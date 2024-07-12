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
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/humans'
require_relative '../../objects/baza/factbases'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::JobTest < Minitest::Test
  def test_starts
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    id = token.start(test_name, test_name, 1, 0, 'n/a', []).id
    job = human.jobs.get(id)
    assert(job.id.positive?)
    assert_equal(id, job.id)
    assert(!job.finished?)
    assert(!job.created.nil?)
    assert(!job.agent.nil?)
    assert(!job.size.nil?)
    assert(!job.errors.nil?)
  end

  def test_cant_finish_twice
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    job = token.start(test_name, test_name, 1, 0, 'n/a', [])
    assert(!job.finished?)
    job.finish!(test_name, 'stdout', 0, 544, 111, 0)
    assert_raises do
      job.finish!(test_name, 'another stdout', 0, 11)
    end
  end

  def test_expires_once
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    job = token.start(test_name, test_name, 1, 0, 'n/a', [])
    assert(!job.expired?)
    job.expire!(Baza::Factbases.new('', ''))
    assert(job.expired?)
    assert_raises do
      job.expire!
    end
  end

  def test_job_secrets
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    n = test_name
    human.secrets.add(n, 'k', 'v')
    human.secrets.add(test_name, 'k', 'v')
    token = human.tokens.add(test_name)
    job = token.start(n, test_name, 1, 0, 'n/a', [])
    assert_equal(1, job.secrets.size)
    assert_equal('k', job.secrets.first['key'])
  end

  def test_valve
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    job = token.start(test_name, test_name, 1, 0, 'n/a', [])
    b = test_name
    x = job.valve.enter(b, 'no reason') { 42 }
    assert_equal(42, x)
    assert_equal(42, job.valve.enter(b, 'another reason') { 55 })
  end
end
