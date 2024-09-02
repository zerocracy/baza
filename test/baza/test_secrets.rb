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
class Baza::SecretsTest < Minitest::Test
  def test_simple_scenario
    human = Baza::Humans.new(fake_pgsql).ensure(fake_name)
    secrets = human.secrets
    n = fake_name
    k = fake_name
    v = fake_name * 10
    secrets.add(n, k, v)
    assert(secrets.exists?(n, k))
    s = secrets.each.to_a.first
    assert_equal(n, s[:name])
    assert_equal(k, s[:key])
    assert_equal(v, s[:value])
    assert_equal(0, s[:jobs])
    assert(!s[:shareable])
    secrets.remove(s[:id])
    assert(!secrets.exists?(n, k))
    assert(secrets.each.to_a.empty?)
  end

  def test_notify_user_after_creating
    loog = Loog::Buffer.new
    human = Baza::Humans.new(fake_pgsql, tbot: Baza::Tbot::Fake.new(loog)).ensure(fake_name)
    id = human.secrets.add(fake_name, fake_name, fake_name * 10)
    assert_includes(loog.to_s, "Secret with ID #{id} has been successfully added.")
  end

  def test_does_not_notify_user_after_fail_creating
    loog = Loog::Buffer.new
    human = Baza::Humans.new(fake_pgsql, tbot: Baza::Tbot::Fake.new(loog)).ensure(fake_name)
    assert_raises do
      human.secrets.add(nil, nil, nil)
    end
    assert_empty(loog.to_s)
  end
end
