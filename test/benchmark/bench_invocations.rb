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

require 'minitest/autorun'
require 'benchmark'
require 'securerandom'
require_relative '../test__helper'
require_relative '../../objects/baza'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class BenchInvocations < Minitest::Test
  def test_invocations_retrieval
    human = fake_human
    swarm = human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
    total = 1000
    total.times do
      swarm.invocations.register(
        SecureRandom.alphanumeric(total), # stdout
        0, # exit code
        11, # msec
        nil, # job
        '0.0.0' # swarm version
      )
    end
    Benchmark.bm do |b|
      b.report('all') { swarm.invocations.each.to_a }
      b.report('with offset') { swarm.invocations.each(offset: total / 2).to_a }
    end
  end
end