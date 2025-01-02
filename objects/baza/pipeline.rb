# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2025 Zerocracy
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

require 'always'
require 'loog'
require 'loog/tee'
require 'backtrace'
require 'logger'
require 'json'
require 'judges/commands/update'
require_relative 'humans'
require_relative 'human'
require_relative 'urror'
require_relative 'errors'
require_relative '../../version'
require_relative 'features'

# Pipeline of jobs.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Pipeline
  attr_reader :pgsql

  def initialize(home, humans, fbs, loog, trails)
    @home = home
    @humans = humans
    @fbs = fbs
    @loog = loog
    @trails = trails
  end

  # Process one job, if there is one that expects processing. If there are no
  # jobs that needs processing, FALSE is returned. Otherwise, it's TRUE.
  #
  # @return [Boolean] TRUE if processing happened, FALSE if no jobs to process
  def process_one
    owner = "baza #{Baza::VERSION} #{Time.now.utc.iso8601}"
    job = @humans.pipe(@fbs, @trails).pop(owner)
    if job.nil?
      @loog.debug('Nothing to process by the pipeline at this time')
      return false
    end
    begin
      process_it(job)
    # rubocop:disable Lint/RescueException
    rescue Exception => e
      # rubocop:enable Lint/RescueException
      @humans.pgsql.transaction do |t|
        if t.exec('SELECT id FROM result WHERE job = $1', [job.id]).empty?
          t.exec(
            'INSERT INTO result (job, stdout, exit, msec) VALUES ($1, $2, 1, 1)',
            [job.id, Backtrace.new(e).to_s]
          )
        else
          t.exec(
            'UPDATE result SET exit = 1, stdout = CONCAT($2, stdout) WHERE job = $1',
            [job.id, Backtrace.new(e).to_s]
          )
        end
        t.exec('UPDATE job SET taken = $1 WHERE id = $2', [e.message[0..255], job.id])
      end
      raise e
    ensure
      job.jobs.human.locks.unlock(job.name, owner)
    end
    @loog.debug("Pipeline finished processing job ##{job.id}")
    true
  end

  private

  def process_it(job)
    @loog.info("Job ##{job.id} starts: #{job.uri1}")
    Dir.mktmpdir do |dir|
      stdout = Loog::Buffer.new(
        level: job.jobs.human.extend(Baza::Human::Roles).admin? ? Logger::DEBUG : Logger::INFO
      )
      log = Loog::Tee.new(stdout, @loog)
      input = File.join(dir, 'base.fb')
      @fbs.load(job.uri1, input)
      log.debug("Factbase loaded from #{job.uri1} into #{input}")
      start = Time.now
      code = run(job, input, log)
      uuid = nil
      if code.zero?
        uuid = @fbs.save(input)
        log.debug("Factbase saved to #{uuid} from #{input}")
      end
      job.finish!(
        uuid,
        escaped(job, stdout.to_s),
        code,
        ((Time.now - start) * 1000).to_i,
        code.zero? ? File.size(input) : nil,
        code.zero? ? Baza::Errors.new(input).count : nil
      )
      @loog.info("Job ##{job.id} finished, exit=#{code}!")
    end
  end

  def run(job, input, stdout)
    alterations(job, input, stdout)
    # rubocop:disable Style/GlobalVars
    $valve = job.valve
    # rubocop:enable Style/GlobalVars
    Dir.mktmpdir do |tdir|
      Judges::Update.new(stdout).run(
        {
          'quiet' => true,
          'summary' => true,
          'max-cycles' => 3, # it will stop on the first cycle if no changes are made
          'log' => false,
          'verbose' => true,
          'option' => job.options.merge({ 'TRAILS_DIR' => tdir }).map { |k, v| "#{k}=#{v}" },
          'lib' => File.join(@home, 'lib')
        },
        [File.join(@home, 'judges'), input]
      )
      Dir[File.join(tdir, '*/*')].each do |f|
        data = File.read(f)
        judge = File.basename(File.dirname(f))
        n = File.basename(f)
        stdout.debug("The trail '#{n}' (#{data.size} bytes) was left by the '#{judge}' judge")
        @trails.add(job, judge, n, JSON.parse(data))
      end
    end
    0
  # rubocop:disable Lint/RescueException
  rescue Exception => e
    # rubocop:enable Lint/RescueException
    stdout.error(Backtrace.new(e))
    1
  end

  def alterations(job, input, stdout)
    alts = job.jobs.human.alterations
    idx = 0
    alts.each(pending: true) do |a|
      next if a[:name] != job.name
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, "alternation-#{a[:id]}-#{idx}"))
        File.write(
          File.join(dir, "alternation-#{a[:id]}-#{idx}/alternation-#{a[:id]}-#{idx}.rb"),
          [
            Baza::Features::TESTS ? '' : 'require "fbe/fb"',
            a[:script]
          ].join("\n")
        )
        stdout.info("Applying alteration ##{a[:id]} (idx:#{idx})...")
        stdout.debug("Ruby script of the alteration ##{a[:id]} is this one:\n#{a[:script]}")
        Judges::Update.new(stdout).run(
          {
            'quiet' => false,
            'summary' => false,
            'max-cycles' => 1,
            'log' => false,
            'verbose' => true,
            'option' => []
          },
          [dir, input]
        )
      end
      job.jobs.human.notify(
        "🍊 We have successfully applied the alteration ##{a[:id]}",
        "to the job `#{job.name}` (##{job.id}),",
        "you can see the log [here](//jobs/#{job.id})."
      )
      alts.complete(a[:id], job.id)
      stdout.info("The alteration ##{a[:id]} was applied successfully\n")
      idx += 1
    end
  end

  # Replace all secrets in the text with *****
  def escaped(job, stdout)
    e = stdout
    job.secrets.each do |s|
      e.gsub(s['value'], '********')
    end
    e
  end
end
