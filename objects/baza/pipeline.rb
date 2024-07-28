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

require 'always'
require 'loog'
require 'loog/tee'
require 'backtrace'
require 'judges/commands/update'
require_relative 'tbot'
require_relative 'humans'
require_relative 'human'
require_relative 'urror'
require_relative 'errors'

# Pipeline of jobs.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Pipeline
  attr_reader :pgsql

  def initialize(jdir, humans, fbs, loog, tbot: Baza::Tbot::Fake.new)
    @jdir = jdir
    @humans = humans
    @fbs = fbs
    @loog = loog
    @tbot = tbot
    @always = Always.new(1).on_error { |e, _| @loog.error(Backtrace.new(e)) }
  end

  def to_s
    @always.to_s
  end

  def backtraces
    @always.backtraces
  end

  def start(pause = 15)
    @always.start(pause) do
      job = pop
      next if job.nil?
      begin
        process_it(job)
      # rubocop:disable Lint/RescueException
      rescue Exception => e
        # rubocop:enable Lint/RescueException
        @humans.pgsql.exec('UPDATE job SET taken = $1 WHERE id = $2', [e.message[0..255], job.id])
        raise e
      end
    end
    @loog.info('Pipeline started')
  end

  def stop
    @always.stop
    @loog.info('Pipeline stopped')
  end

  # Is it empty? Nothing to process any more?
  def empty?
    humans.pgsql.exec('SELECT id FROM job WHERE taken IS NULL').empty?
  end

  private

  def process_it(job)
    @loog.info("Job ##{job.id} starts: #{job.uri1}")
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'input.fb')
      @fbs.load(job.uri1, input)
      start = Time.now
      stdout = Loog::Buffer.new
      code = run(job, input, Loog::Tee.new(stdout, @loog))
      uuid = code.zero? ? @fbs.save(input) : nil
      job.finish!(
        uuid,
        escaped(job, stdout.to_s),
        code,
        ((Time.now - start) * 1000).to_i,
        code.zero? ? File.size(input) : nil,
        code.zero? ? Baza::Errors.new(input).count : nil
      )
      if code.zero?
        errs = Baza::Errors.new(input).count
        unless errs.zero?
          @tbot.notify(
            job.jobs.human,
            "⚠️ The job [##{job.id}](https://www.zerocracy.com/jobs/#{job.id}) (`#{job.name}`)",
            "finished with #{errs} error#{errs == 1 ? '' : 's'}.",
            'You better pay attention to it ASAP, before it gets too late.'
          )
        end
      else
        job.jobs.human.notify(
          "💔 The job [##{job.id}](https://www.zerocracy.com/jobs/#{job.id}) has failed :(",
          'This most probably means that there is an internal error on our server.',
          'Please, report this situation to us by ',
          '[submitting an issue](https://github.com/zerocracy/baza/issues) and',
          "mentioning this job ID: `#{job.id}`."
        )
      end
      @loog.info("Job ##{job.id} finished, exit=#{code}!")
    end
  end

  def pop
    require_relative '../../version'
    me = "baza #{Baza::VERSION} #{Time.now.utc.iso8601}"
    rows = @humans.pgsql.exec('UPDATE job SET taken = $1 WHERE taken IS NULL RETURNING id', [me])
    return nil if rows.empty?
    @humans.job_by_id(rows[0]['id'].to_i)
  end

  def run(job, input, stdout)
    # rubocop:disable Style/GlobalVars
    $valve = job.valve
    # rubocop:enable Style/GlobalVars
    Judges::Update.new(stdout).run(
      {
        'quiet' => true,
        'summary' => true,
        'max-cycles' => 3, # it will stop on the first cycle if no changes are made
        'log' => false,
        'verbose' => job.jobs.human.extend(Baza::Human::Admin).admin?,
        'option' => options(job).map { |k, v| "#{k}=#{v}" },
        'lib' => File.join(@jdir, 'lib')
      },
      [File.join(@jdir, 'judges'), input]
    )
    0
  # rubocop:disable Lint/RescueException
  rescue Exception => e
    # rubocop:enable Lint/RescueException
    stdout.error(Backtrace.new(e))
    1
  end

  # Create list of options for the job.
  # @param [Baza::Job] job The job
  # @return [Hash] Option/value pairs
  def options(job)
    @humans.find('yegor256').secrets.each.to_a
      .select { |s| s[:shareable] }.to_h { |s| [s[:key], s[:value]] }
      .merge(
        job.metas.to_h do |m|
          a = m.split(':', 2)
          a[1] = '' if a.size == 1
          a
        end
      )
      .merge(job.secrets.to_h { |s| [s['key'], s['value']] })
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
