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

require 'loog'
require 'backtrace'
require_relative 'humans'
require_relative 'urror'

# Pipeline of jobs.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Pipeline
  attr_reader :pgsql

  def initialize(fbs, loog)
    @loog = loog
    @jobs = Queue.new
    @fbs = fbs
    @busy = false
  end

  def start
    @thread ||= Thread.new do
      loop do
        @busy = false
        job = @jobs.pop
        @busy = true
        @loog.info("Job ##{job.id} starts: #{job.uri1}")
        Dir.mktmpdir do |dir|
          input = File.join(dir, 'input.fb')
          @fbs.load(job.uri1, input)
          output = File.join(dir, 'output.fb')
          start = Time.now
          stdout = Loog::Buffer.new
          code = run(input, output, stdout)
          uuid = code.zero? ? @fbs.save(output) : nil
          job.finish(uuid, stdout.to_s, code, ((Time.now - start) * 1000).to_i)
          @loog.info("Job ##{job.id} finished, exit=#{code}!")
        end
      rescue StandardError => e
        @loog.error(Backtrace.new(e))
      end
    end
    @loog.info('Pipeline started')
  end

  def stop
    @thread.terminate
    @loog.info('Pipeline stopped')
  end

  def update(humans)
    q =
      'SELECT human.id AS h, job.id AS j FROM job ' \
      'JOIN token ON job.token = token.id ' \
      'JOIN human ON token.human = human.id ' \
      'LEFT JOIN result ON result.job = job.id ' \
      'WHERE result.id IS NULL'
    humans.pgsql.exec(q).each do |row|
      push(humans.get(row['h'].to_i).jobs.get(row['j'].to_i))
    end
    @loog.info("Pipeline updated with #{@jobs.size} jobs previously existed in the DB")
  end

  def push(job)
    @jobs << job
    @loog.info("Job ##{job.id} added to the queue: #{job.uri1}")
  end

  # Wait for the pipeline to get empty and complete all tasks.
  # This is mostly used for unit
  # testing. The +max+ argument is the number of seconds to wait maximum.
  def wait(max = 2)
    start = Time.now
    loop do
      break if @jobs.empty? && !@busy
      sleep 0.01
      raise 'The pipeline is still busy' if Time.now - start > max
    end
    yield
  end

  private

  def run(input, output, buf)
    FileUtils.cp(input, output)
    buf.info('Simply copied input FB into output FB')
    0
  end
end
