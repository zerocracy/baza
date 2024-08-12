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
require 'factbase'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/humans'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::AlterationsTest < Minitest::Test
  module Fbe
    def self.fb
      @fb ||= Factbase.new
    end
  end

  def test_simple_scenario
    human = fake_human
    alterations = human.alterations
    n = fake_name
    script = 'puts "Hello, world!"'
    alterations.add(n, 'ruby', script:)
    a = alterations.each.to_a.first
    assert_equal(n, a[:name])
    assert_equal(script, a[:script])
    assert_equal(0, a[:jobs])
    alterations.remove(a[:id])
    assert(alterations.each.to_a.empty?)
  end

  def test_with_template
    human = fake_human
    alterations = human.alterations
    n = fake_name
    alterations.add(n, 'pmp', { area: 'quality', param: 'qos_interval', value: '4' })
    a = alterations.each.to_a.first
    assert(!a[:script].nil?)
  end

  def test_pmp_template
    human = fake_human
    alterations = human.alterations
    n = fake_name
    alterations.add(n, 'pmp', { area: 'quality', param: 'qos_interval', value: '42' })
    ruby = alterations.each.to_a.first[:script]
    Fbe.fb.query('(always)').delete!
    Fbe.fb.insert.foo = 42
    f = Fbe.fb.insert
    f.what = 'pmp'
    f.area = 'quality'
    f.qos_interval = 7
    f.other = 33
    # rubocop:disable Security/Eval
    eval(ruby) # full script here
    # rubocop:enable Security/Eval
    assert_equal(2, Fbe.fb.size)
    f = Fbe.fb.query('(eq what "pmp")').each.to_a.first
    assert_equal('pmp', f.what)
    assert_equal('quality', f.area)
    assert_equal(33, f.other)
    assert_equal(42, f.qos_interval)
  end

  def test_payout_template
    human = fake_human
    alterations = human.alterations
    n = fake_name
    alterations.add(n, 'payout', { who: '444', payout: '100' })
    ruby = alterations.each.to_a.first[:script]
    Fbe.fb.query('(always)').delete!
    f = Fbe.fb.insert
    f.what = 'resolved-bug-was-rewarded'
    f.award = 15
    f.who = 444
    f.when = Time.now - (5 * 24 * 60 * 60)
    # rubocop:disable Security/Eval
    eval(ruby) # full script here
    # rubocop:enable Security/Eval
    assert_equal(2, Fbe.fb.size)
    r = Fbe.fb.query('(eq what "reconciliation")').each.to_a.first
    assert_equal(-85, r.balance)
    assert_equal(15, r.awarded)
    assert_equal(100, r.payout)
    # rubocop:disable Security/Eval
    eval(ruby) # full script here
    # rubocop:enable Security/Eval
    assert_equal(2, Fbe.fb.size)
    r = Fbe.fb.query('(eq what "reconciliation")').each.to_a.first
    assert_equal(-185, r.balance)
    assert_equal(15, r.awarded)
    assert_equal(100, r.payout)
  end

  def test_all_variable_leakage
    human = fake_human
    alterations = human.alterations
    n = fake_name
    %w[pmp payout].each do |t|
      alterations.add(n, t, %w[area param value who payout].to_h { |k| [k.to_sym, "\u0023{exit}"] })
    end
    alterations.each do |a|
      # rubocop:disable Security/Eval
      eval(a[:script]) # full script here
      # rubocop:enable Security/Eval
    rescue StandardError
      # ignore it, it's OK (as long as the process doesn't die)
    end
  end
end
