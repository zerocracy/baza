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
  def test_null_notify
    tbot = Baza::Tbot.new(fake_pgsql, '')
    humans = Baza::Humans.new(fake_pgsql)
    human = humans.ensure(fake_name)
    tbot.notify(human, 'Hello, look: foo/foo#444')
  end

  def test_posts_correctly
    humans = Baza::Humans.new(fake_pgsql)
    human = humans.ensure(fake_name)
    tbot = Baza::Tbot.new(fake_pgsql, '')
    tbot.auth(human, tbot.entry(55))
    tbot.notify(human, 'Hello, **dude**! Read [this](//dash)!  ')
    sent = tbot.tp.sent[1]
    [
      'Hello, **dude**!',
      'Read [this](https://www.zerocracy.com/dash)'
    ].each { |t| assert(sent.include?(t), sent) }
  end

  def test_to_string
    tbot = Baza::Tbot::Spy.new(Baza::Tbot.new(fake_pgsql, ''), 0)
    assert(!tbot.to_s.nil?)
    assert(tbot.to_s.match?(%r{^[0-9]/[0-9]/[0-9]$}))
  end

  def test_auth_wrong
    humans = Baza::Humans.new(fake_pgsql)
    human = humans.ensure(fake_name)
    tbot = Baza::Tbot.new(fake_pgsql, '')
    assert_raises(Baza::Urror) { tbot.auth(human, 'wrong-secret') }
  end

  def test_double_auth
    tbot = Baza::Tbot.new(fake_pgsql, '')
    secret = tbot.entry(55)
    humans = Baza::Humans.new(fake_pgsql)
    first = humans.ensure(fake_name)
    tbot.auth(first, secret)
    second = humans.ensure(fake_name)
    assert_raises(Baza::Urror) { tbot.auth(second, 'another secret') }
  end

  def test_auth_right
    tbot = Baza::Tbot.new(fake_pgsql, '')
    secret = tbot.entry(42)
    humans = Baza::Humans.new(fake_pgsql)
    human = humans.ensure(fake_name)
    chat = tbot.auth(human, secret)
    assert(chat.positive?)
    tbot.notify(human, 'Hey')
  end
end
