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
    human = fake_human
    tokens = human.tokens
    assert(tokens.empty?)
  end

  def test_creates_token
    human = fake_human
    tokens = human.tokens
    name = fake_name
    token = tokens.add(name)
    assert_equal(token.name, name)
    assert(!tokens.empty?)
  end

  def test_deactivates_token
    human = fake_human
    tokens = human.tokens
    name = fake_name
    assert_equal(0, tokens.size)
    token = tokens.add(name)
    assert_equal(1, tokens.size)
    assert(token.active?)
    tokens.get(token.id).deactivate!
    assert_equal(1, tokens.size)
    assert(!token.active?)
  end

  def test_finds_token
    human = fake_human
    tokens = human.tokens
    name = fake_name
    token = tokens.add(name)
    assert_equal(token.id, tokens.find(token.text).id)
  end
end
