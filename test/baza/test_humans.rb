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
class Baza::HumansTest < Baza::Test
  def app
    Sinatra::Application
  end

  def test_simple_fetching
    humans = Baza::Humans.new(fake_pgsql, tbot: Baza::Tbot::Fake.new(fake_loog))
    login = fake_name
    human = humans.ensure("#{login}_ABC")
    assert(humans.exists?("#{login}_aBc"))
    assert_equal(human.github, "#{login}_abc")
    assert_equal(human.id, humans.find("#{login}_abC").id)
  end

  def test_donate_when_small
    humans = Baza::Humans.new(fake_pgsql, tbot: Baza::Tbot::Fake.new(fake_loog))
    human = humans.ensure(fake_name)
    fake_job(human).finish!(fake_name, 'stdout', 0, 544, 111, 0)
    assert(!human.account.balance.positive?)
    humans.donate(amount: 100_000, days: 0)
    assert(human.account.balance.positive?)
  end

  def test_donate_even_empty
    humans = Baza::Humans.new(fake_pgsql, tbot: Baza::Tbot::Fake.new(fake_loog))
    human = humans.ensure(fake_name)
    assert(human.account.balance.zero?)
    humans.donate
    b = human.account.balance
    assert(b.positive?)
    humans.donate
    assert_equal(b, human.account.balance)
  end

  def test_donate_only_once
    humans = Baza::Humans.new(fake_pgsql, tbot: Baza::Tbot::Fake.new(fake_loog))
    human = humans.ensure(fake_name)
    fake_job(human).finish!(fake_name, 'x', 0, 544, 111, 0)
    assert(!human.account.balance.positive?)
    humans.donate(amount: 1000, days: 0)
    assert(human.account.balance.positive?)
    fake_job(human).finish!(fake_name, 'x', 0, 8440, 111, 0)
    assert(!human.account.balance.positive?)
    humans.donate(amount: 1000, days: 10)
    assert(!human.account.balance.positive?)
  end

  def test_passes_tbot_further
    passed = []
    tbot = others { |*args| passed << args }
    humans = Baza::Humans.new(fake_pgsql, tbot:)
    human = humans.ensure(fake_name)
    human.account.top_up(42_000, 'need it')
    token = human.tokens.add(fake_name)
    id = token.start(fake_name, fake_name, 1, 0, 'n/a', [], '192.168.1.1').id
    job = human.jobs.get(id)
    job.valve.enter('badge', 'why') { 42 }
    assert_equal(3, passed.size, passed)
  end

  def test_verify_one_job
    WebMock.disable_net_connect!
    job = fake_job
    stub_request(:get, %r{^https://api.github.com/repos/[^/]+/[^/]+/actions/runs/.*$}).to_return(status: 404)
    job.jobs.human.humans.verify_one_job(app.settings.ipgeolocation, app.settings.zache) do |_job, verdict|
      assert(verdict.start_with?('FAKE: '))
    end
  end
end
