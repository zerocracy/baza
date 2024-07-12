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
class Baza::ValveTest < Minitest::Test
  def test_simple_scenario
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    valves = human.valves
    n = test_name
    b = test_name
    x = valves.enter(n, b, 'why') { 42 }
    assert_equal(42, x)
    assert(valves.each.to_a.first[:id].positive?)
    assert(!valves.each.to_a.first[:created].nil?)
    v = valves.each.to_a.first
    assert_equal(n, v[:name])
    assert_equal(b, v[:badge])
    assert_equal(42, v[:result])
    assert_equal('why', v[:why])
    y = valves.enter(n, b, 'why') { 55 }
    assert_equal(42, y)
    valves.remove(n, b)
    assert(valves.each.to_a.empty?)
  end

  def test_with_exception
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    valves = human.valves
    n = test_name
    b = test_name
    assert_raises { valves.enter(n, b, 'why') { raise 'intentional' } }
    assert_equal(42, valves.enter(n, b, 'why') { 42 })
  end

  def test_with_two_threads
    human = Baza::Humans.new(test_pgsql).ensure(test_name)
    valves = human.valves
    n = test_name
    b = test_name
    entered = false
    Thread.new do
      valves.enter(n, b, 'no reason') do
        entered = true
        sleep 0.05
        42
      end
    end
    loop { break if entered }
    assert_equal(42, valves.enter(n, b, 'why') { 55 })
  end
end
