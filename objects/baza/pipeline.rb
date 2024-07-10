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
require_relative 'humans'
require_relative 'urror'
require_relative 'errors'

# Pipeline of jobs.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Pipeline
  attr_reader :pgsql

  def initialize(jdir, humans, fbs, loog)
    @jdir = jdir
    @humans = humans
    @fbs = fbs
    @loog = loog
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
      rescue StandardError => e
        @humans.pgsql.exec('UPDATE job SET taken = $1 WHERE id = $2', [e.message, job.id])
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
        'max-cycles' => 2,
        'log' => true,
        'verbose' => true,
        'option' => job.secrets.map { |s| "#{s['key']}=#{s['value']}" },
        'lib' => File.join(@jdir, 'lib')
      },
      [File.join(@jdir, 'judges'), input]
    )
    0
  rescue StandardError => e
    stdout.error(Backtrace.new(e))
    1
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
