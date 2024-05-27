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
require_relative 'humans'
require_relative 'urror'

# Pipeline of jobs.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Pipeline
  attr_reader :pgsql

  def initialize(loog)
    @loog = loog
    @jobs = Queue.new
  end

  def start
    @thread ||= Thread.new do
      loop do
        job = @jobs.pop
        @loog.info("Job #{job.id} taken from the queue, started...")
        job.finish("s3://#{job.id}", 'stdout', 0, 42)
        @loog.info("Job #{job.id} finished!")
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
    @loog.info("Pipeline updated with #{@jobs.size}")
  end

  def push(job)
    @jobs << job
    @loog.info("Job #{job.id} added to the jobs")
  end

  def wait
    loop do
      break if @jobs.empty?
      sleep 0.01
    end
    yield
  end
end
