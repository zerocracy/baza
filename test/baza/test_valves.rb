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
class Baza::ValvesTest < Baza::Test
  def test_simple_scenario
    human = fake_human
    valves = human.valves
    n = fake_name
    b = fake_name
    x = valves.enter(n, b, 'why', nil) { 42 }
    assert_equal(42, x)
    assert(!valves.empty?)
    assert(valves.exists?(b))
    v = valves.each.to_a.first
    assert(v[:id].positive?)
    assert(!v[:created].nil?)
    assert_equal(v[:id], valves.get(v[:id]).id)
    assert_equal(n, v[:name])
    assert_equal(b, v[:badge])
    assert_equal(42, v[:result])
    assert_equal('why', v[:why])
    assert_equal(0, v[:jobs])
    y = valves.enter(n, b, 'why', nil) { 55 }
    assert_equal(42, y)
    valves.remove(v[:id])
    assert(valves.each.to_a.empty?)
  end

  def test_with_exception
    human = fake_human
    valves = human.valves
    n = fake_name
    b = fake_name
    assert_raises { valves.enter(n, b, 'why', nil) { raise 'intentional' } }
    assert_equal(42, valves.enter(n, b, 'why', nil) { 42 })
  end

  def test_with_two_threads
    human = fake_human
    valves = human.valves
    n = fake_name
    b = fake_name
    entered = false
    Thread.new do
      valves.enter(n, b, 'no reason', nil) do
        entered = true
        sleep 0.05
        42
      end
    end
    loop { break if entered }
    assert_equal(42, valves.enter(n, b, 'why', nil) { 55 })
  end

  def test_escapes_for_tbot
    loog = Loog::Buffer.new
    human = Baza::Humans.new(fake_pgsql, tbot: Baza::Tbot::Fake.new(loog)).ensure(fake_name)
    valves = human.valves
    n = fake_name
    b = fake_name
    valves.enter(n, b, 'you @jeff-lebowski is [awesome] in foo/foo-x.j#42', nil) { 42 }
    assert_match(%r{A new \[valve\]\(//valves/\d+\)}, loog.to_s)
    assert_include(
      loog.to_s,
      '"you [@jeff-lebowski](https://github.com/jeff-lebowski) is \[awesome\]',
      'in [foo/foo-x.j#42](https://github.com/foo/foo-x.j/issues/42)',
      'The result is `42`'
    )
  end

  def test_link_with_job
    job = fake_job
    valves = job.jobs.human.valves
    valves.enter(fake_name, fake_name, 'hi', job.id) { 42 }
    assert_equal(job.id, valves.each.to_a.first[:job])
  end

  def test_reset_id
    job = fake_job
    valves = job.jobs.human.valves
    valves.enter(fake_name, fake_name, 'hi', job.id) { 42 }
    id = valves.each.to_a.first[:id]
    valves.reset(id, 'another')
    assert_equal('another', valves.each.to_a.first[:result])
  end
end
