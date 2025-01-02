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

require 'securerandom'
require 'minitest/hooks/test'
require_relative '../test__helper'
require_relative '../../objects/baza'

# Extension of Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::BenchTest < Baza::Test
  include Minitest::Hooks

  def before_all
    super

    @bench_human = fake_human('bench')
    @bench_total = 100
    @bench_names = (0..@bench_total / 10).map { fake_name }

    acc = @bench_human.account
    @bench_total.times do
      acc.top_up(42, SecureRandom.alphanumeric(100))
    end

    @bench_total.times do
      s = @bench_human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
      @bench_total.times do
        s.invocations.register(
          SecureRandom.alphanumeric(@bench_total), # stdout
          0, # exit code
          555, # msec
          nil, # job
          '0.0.0' # swarm version
        )
      end
      @bench_total.times do
        s.releases.start(
          SecureRandom.alphanumeric(@bench_total), # tail
          fake_name # secret
        )
      end
    end

    token = @bench_human.tokens.add(fake_name)
    @bench_total.times do
      token.start(
        fake_name, # job name
        fake_name, # URI of the factbase file
        1, # size of .fb file
        0, # how many errors
        'n/a', # user-agent
        [], # metas
        '192.168.1.1' # IP of sender
      )
    end

    @bench_total.times do
      job = token.start(
        @bench_names.sample, # job name
        fake_name, # URI of the factbase file
        1, # size of .fb file
        0, # how many errors
        'n/a', # user-agent
        (0..10).map { SecureRandom.alphanumeric(@bench_total / 10) }, # metas
        '192.168.1.1' # IP of sender
      )
      job.finish!(
        fake_name, # uri2
        SecureRandom.alphanumeric(@bench_total), # stdout
        0, # exit code
        555, # msec
        4444, # size
        0 # count of errors
      )
      swarm = @bench_human.swarms.each.to_a.first
      (@bench_total / 100).times do
        swarm.invocations.register(
          SecureRandom.alphanumeric(@bench_total), # stdout
          0, # exit code
          222, # msec
          job, # job
          '0.0.0' # swarm version
        )
      end
    end

    jobs = (0..@bench_total / 10).map { fake_job }
    @bench_total.times do
      job = jobs.sample
      @bench_human.valves.enter(job.name, fake_name, fake_name, job.id) { fake_name }
    end
  end
end
