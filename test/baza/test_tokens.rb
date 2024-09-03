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

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::TokensTest < Minitest::Test
  def test_emptiness_checks
    tokens = fake_human.tokens
    assert(tokens.empty?)
  end

  def test_creates_token
    tokens = fake_human.tokens
    name = fake_name
    token = tokens.add(name)
    assert_equal(token.name, name)
    assert(!tokens.empty?)
  end

  def test_notify_user_after_creating
    loog = Loog::Buffer.new
    human = Baza::Humans.new(fake_pgsql, tbot: Baza::Tbot::Fake.new(loog)).ensure(fake_name)
    name = fake_name
    token = human.tokens.add(name)
    assert_equal(token.name, name)
    assert_includes(loog.to_s, "Token with the name '#{name}' has been created successfully")
  end

  def test_does_not_notify_user_after_fail_creating
    loog = Loog::Buffer.new
    human = Baza::Humans.new(fake_pgsql, tbot: Baza::Tbot::Fake.new(loog)).ensure(fake_name)
    assert_raises(Baza::Urror) do
      human.tokens.add('')
    end
    assert_empty(loog.to_s)
    assert_raises(Baza::Urror) do
      human.tokens.add(fake_name * 10)
    end
    assert_empty(loog.to_s)
    assert_raises(Baza::Urror) do
      human.tokens.add('0')
    end
    assert_empty(loog.to_s)
    name = fake_name
    token = human.tokens.add(name)
    assert_equal(1, loog.to_s.split("\n").size)
    assert_raises(Baza::Urror) do
      human.tokens.add(name)
    end
    assert_equal(1, loog.to_s.split("\n").size)
    token.deactivate!
    assert_raises(Baza::Urror) do
      human.tokens.add(name)
    end
    assert_equal(1, loog.to_s.split("\n").size)
  end

  def test_deactivates_token
    tokens = fake_human.tokens
    assert_equal(0, tokens.size)
    token = tokens.add(fake_name)
    assert_equal(1, tokens.size)
    assert(token.active?)
    tokens.get(token.id).deactivate!
    assert_equal(1, tokens.size)
    assert(!tokens.get(token.id).active?)
  end

  def test_finds_token
    tokens = fake_human.tokens
    name = fake_name
    token = tokens.add(name)
    assert_equal(token.id, tokens.find(token.text).id)
  end
end
