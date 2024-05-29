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

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::JobsTest < Minitest::Test
  def test_all_fields
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    id = token.start(test_name, test_name).id
    job = human.jobs.get(id)
    assert_equal(id, job.id)
    assert(!job.name.nil?)
    assert(!job.uri1.nil?)
  end

  def test_emptiness_checks
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    jobs = human.jobs
    assert(jobs.empty?)
  end

  def test_start_and_finish
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    job = token.start(test_name, test_name)
    assert(!human.jobs.get(job.id).finished?)
    job.finish!(test_name, 'stdout', 0, 544)
    assert(human.jobs.get(job.id).finished?)
    assert(!human.jobs.empty?)
    found = 0
    human.jobs.each do |j|
      found += 1
      assert(j.finished?)
    end
    assert_equal(1, found)
  end

  def test_iterates_with_offset
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    token.start(test_name, test_name)
    found = 0
    human.jobs.each(offset: 1) do |_|
      found += 1
    end
    assert_equal(0, found)
  end

  def test_finds_recent_job
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    name = "#{test_name}-a"
    token.start(name, test_name).finish!(test_name, 'stdout', 0, 544)
    token.start("#{test_name}-b", test_name)
    id2 = token.start(name, test_name).id
    assert(human.jobs.name_exists?(name))
    assert_equal(id2, human.jobs.recent(name).id)
  end

  def test_prohibits_more_than_one_running_job
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    token = human.tokens.add(test_name)
    name = test_name
    token.start(name, test_name)
    assert_raises do
      token.start(name, test_name)
    end
  end
end
