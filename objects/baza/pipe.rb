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
require_relative 'errors'

# Pipe of jobs.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Pipe
  def initialize(humans, fbs)
    @humans = humans
    @fbs = fbs
  end

  def pop(owner)
    rows = @humans.pgsql.exec(
      [
        'UPDATE job SET taken = $1 WHERE id = (',
        '  SELECT job.id FROM job',
        '  LEFT JOIN result ON result.job = job.id',
        '  WHERE result.id IS NULL AND taken IS NULL',
        '  LIMIT 1)',
        'RETURNING id'
      ],
      [owner]
    )
    return nil if rows.empty?
    @humans.job_by_id(rows.first['id'].to_i)
  end

  # Pack one job into a ZIP file.
  #
  # @param [Baza::Job] job The job to pack
  # @param [String] file The path to .zip file to create
  def pack(job, file)
    Dir.mktmpdir do |dir|
      Zip::File.open(file, create: true) do |zip|
        fb = File.join(dir, "#{job.id}.fb")
        @fbs.load(job.uri1, fb)
        zip.add(File.basename(fb), fb)
        json = File.join(dir, "#{job.id}.json")
        File.write(
          json,
          JSON.pretty_generate(
            {
              id: job.id,
              name: job.name,
              human: job.jobs.human.id
            }
          )
        )
        zip.add(File.basename(json), json)
        alts = job.jobs.human.alterations
        alts.each(pending: true) do |a|
          next if a[:name] != job.name
          af = File.join(dir, "alteration-#{a[:id]}.rb")
          File.write(af, a[:script])
          zip.add(File.basename(af), af)
        end
      end
    end
  end

  # Unpack a ZIP file and finish the job with the information from it.
  #
  # @param [Baza::Job] job The job to pack
  # @param [String] file The path to .zip file to read
  def unpack(job, file)
    Dir.mktmpdir do |dir|
      Zip::File.open(file) do |zip|
        zip.each do |entry|
          entry.extract(File.join(dir, entry.name))
        end
      end
      %w[json fb stdout].each do |ext|
        f = File.join(dir, "#{job.id}.#{ext}")
        raise Baza::Urror, "The #{File.basename(f)} file is missing" unless File.exist?(f)
      end
      meta = JSON.parse(File.read(File.join(dir, "#{job.id}.json")))
      %w[exit msec].each do |a|
        raise Baza::Urror, "The '#{a}' is missing in JSON" if meta[a].nil?
      end
      fb = File.join(dir, "#{job.id}.fb")
      uri = @fbs.save(fb)
      job.finish!(
        uri,
        File.binread(File.join(dir, "#{job.id}.stdout")),
        meta['exit'],
        meta['msec'],
        meta['exit'].zero? ? File.size(fb) : nil,
        meta['exit'].zero? ? Baza::Errors.new(fb).count : nil
      )
    end
  end
end
