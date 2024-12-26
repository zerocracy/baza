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
require_relative '../../objects/baza/humans'
require_relative '../../objects/baza/factbases'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class BenchPipe < Minitest::Test
  def test_pop
    human = fake_human
    token = human.tokens.add(fake_name)
    total = 1000
    total.times do
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
    humans = fake_humans
    fbs = Baza::Factbases.new('', '', loog: fake_loog)
    pipe = Baza::Pipe.new(humans, fbs, Baza::Trails.new(fake_pgsql), loog: fake_loog)
    Benchmark.bm do |b|
      b.report('just pop') do
        total.times do
          job = pipe.pop(fake_name)
          job.finish!(
            fake_name, # uri2
            SecureRandom.alphanumeric(total), # stdout
            0, # exit code
            555, # msec
            4444, # size
            0 # count of errors
          )
        end
      end
    end
  end
end
