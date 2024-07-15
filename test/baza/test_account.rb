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
class Baza::AccountTest < Minitest::Test
  def test_simple_receipt
    human = Baza::Humans.new(fake_pgsql).ensure(fake_name)
    acc = human.account
    assert_equal(0, acc.balance)
    acc.top_up(42, 'nothing')
    acc.top_up(-10, 'foo')
    assert_equal(32, acc.balance)
    acc.top_up(-32, 'fun')
    assert_equal(0, acc.balance)
  end

  def test_fetch_bars
    human = Baza::Humans.new(fake_pgsql).ensure(fake_name)
    acc = human.account
    (-10..0).each do |week|
      created = Time.now - (week * 7 * 24 * 60 * 60)
      acc.top_up(42, 'something', created:)
      acc.top_up(-10, 'foo', created:)
    end
    bars = acc.bars
    assert(!bars.empty?)
    bars.each do |b|
      assert(!b[:week].nil?)
      assert(!b[:credit].nil?)
      assert(!b[:debit].nil?)
      assert(!b[:credit].negative?)
      assert(!b[:debit].negative?)
    end
  end
end
