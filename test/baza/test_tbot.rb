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
require 'loog'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/tbot'
require_relative '../../objects/baza/urror'
require_relative '../../objects/baza/humans'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::TbotTest < Minitest::Test
  def test_simple_notify
    tbot = Baza::Tbot.new(test_pgsql, '', loog: Loog::VERBOSE)
    humans = Baza::Humans.new(test_pgsql)
    human = humans.ensure(test_name)
    tbot.notify(human, 'Hello, how are you?')
  end

  def test_auth_wrong
    humans = Baza::Humans.new(test_pgsql)
    human = humans.ensure(test_name)
    tbot = Baza::Tbot.new(test_pgsql, '', loog: Loog::VERBOSE)
    assert_raises(Baza::Urror) { tbot.auth(human, 'wrong-secret') }
  end

  def test_double_auth
    tbot = Baza::Tbot.new(test_pgsql, '', loog: Loog::VERBOSE)
    secret = tbot.entry(55)
    humans = Baza::Humans.new(test_pgsql)
    first = humans.ensure(test_name)
    tbot.auth(first, secret)
    second = humans.ensure(test_name)
    assert_raises(Baza::Urror) { tbot.auth(second, secret) }
  end

  def test_auth_right
    tbot = Baza::Tbot.new(test_pgsql, '', loog: Loog::VERBOSE)
    secret = tbot.entry(42)
    humans = Baza::Humans.new(test_pgsql)
    human = humans.ensure(test_name)
    chat = tbot.auth(human, secret)
    assert(chat.positive?)
  end
end
