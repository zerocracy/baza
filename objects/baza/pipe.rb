# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'zip'
require 'json'
require 'fileutils'
require_relative 'errors'
require_relative 'zip'

# Pipe of jobs.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Pipe
  def initialize(humans, fbs, trails, loog: Loog::NULL)
    @humans = humans
    @fbs = fbs
    @trails = trails
    @loog = loog
  end

  def pop(owner)
    rows = @humans.pgsql.exec(
      [
        'UPDATE job SET taken = $1 WHERE id = (',
        '  SELECT job.id FROM job',
        '  LEFT JOIN result ON result.job = job.id',
        '  WHERE result.id IS NULL AND (taken IS NULL OR taken = $1)',
        '  LIMIT 1)',
        'RETURNING id'
      ],
      [owner]
    )
    if rows.empty?
      @loog.debug('There are no not-yet-taken jobs in the pipeline now')
      return nil
    end
    job = @humans.job_by_id(rows.first['id'].to_i)
    if job.name == 'test' && job.jobs.human.github == 'yegor256'
      if owner.start_with?('baza')
        job.untake!
        @loog.debug("Job ##{job.id} can't be taken by #{owner.inspect}, it's for testing only")
        return nil
      end
    # Because we are still testing:
    elsif owner.start_with?('swarm:') && ENV['RACK_ENV'] != 'test'
      job.untake!
      @loog.debug("Job ##{job.id} can't be used by swarms, we are still testing")
      return nil
    end
    @loog.debug("Job ##{job.id} popped out")
    job
  end

  # Pack one job into a ZIP file.
  #
  # @param [Baza::Job] job The job to pack
  # @param [String] file The path to .zip file to create
  def pack(job, file)
    Dir.mktmpdir do |dir|
      @fbs.load(job.uri1, File.join(dir, 'base.fb'))
      alts = job.jobs.human.alterations.each(pending: true).to_a.select { |a| a[:name] == job.name }
      File.write(
        File.join(dir, 'job.json'),
        JSON.pretty_generate(
          {
            id: job.id,
            name: job.name,
            packed: Time.now.utc.iso8601,
            human: job.jobs.human.github,
            alterations: alts.map { |a| a[:id] },
            options: job.options
          }
        )
      )
      alts.each do |a|
        t = "alteration-#{a[:id]}"
        rb = File.join(dir, "#{t}/#{t}.rb")
        FileUtils.mkdir_p(File.dirname(rb))
        File.write(rb, a[:script])
      end
      Baza::Zip.new(file, loog: @loog).pack(dir)
    end
    @loog.debug("Job ##{job.id} packed into ZIP (#{File.size(file)} bytes)")
  end

  # Unpack a ZIP file and finish the job with the information from it.
  #
  # @param [Baza::Job] job The job to pack
  # @param [String] file The path to .zip file to read
  def unpack(job, file)
    Dir.mktmpdir do |dir|
      Baza::Zip.new(file, loog: @loog).unpack(dir)
      ['job.json', 'base.fb', 'stdout.txt'].each do |n|
        f = File.join(dir, n)
        raise Baza::Urror, "The #{File.basename(f)} file is missing" unless File.exist?(f)
      end
      meta = JSON.parse(File.read(File.join(dir, 'job.json')))
      %w[exit msec].each do |a|
        raise Baza::Urror, "The '#{a}' is missing in JSON" if meta[a].nil?
      end
      fb = File.join(dir, 'base.fb')
      uri = @fbs.save(fb)
      job.finish!(
        uri,
        File.binread(File.join(dir, 'stdout.txt')),
        meta['exit'],
        meta['msec'],
        meta['exit'].zero? ? File.size(fb) : nil,
        meta['exit'].zero? ? Baza::Errors.new(fb).count : nil
      )
      Dir[File.join(dir, 'alteration-*/stdout.txt')].each do |f|
        alt = File.basename(File.dirname(f)).split('-', 2)[1].to_i
        job.jobs.human.notify(
          "🍊 We have successfully applied the alteration ##{alt}",
          "to the job `#{job.name}` (##{job.id}),",
          "you can see the log [here](//jobs/#{job.id})."
        )
        job.jobs.human.alterations.complete(alt, job.id)
        @loog.debug("The job ##{job.id} applied the alteration ##{alt}")
      end
      Dir[File.join(dir, 'trails/*/*')].each do |f|
        data = File.read(f)
        judge = File.basename(File.dirname(f))
        n = File.basename(f)
        @trails.add(job, judge, n, JSON.parse(data))
        @loog.debug("The trail '#{n}' (#{data.size} bytes) was left by the '#{judge}' judge")
      end
    end
    @loog.debug("The job ##{job.id} unpacked from ZIP (#{File.size(file)} bytes)")
  end
end
