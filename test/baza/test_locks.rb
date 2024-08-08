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
require_relative '../../objects/baza/locks'
require_relative '../../objects/baza/humans'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::LocksTest < Minitest::Test
  def test_simple_locking_scenario
    human = Baza::Humans.new(fake_pgsql).ensure(fake_name)
    locks = human.locks
    owner = "#{fake_name} #{fake_name} #{fake_name} --"
    n = fake_name
    locks.lock(n, owner)
    locks.lock(n, owner)
    e = assert_raises(Baza::Urror) { locks.lock(n, fake_name) }
    assert(e.message.include?('is occupied by another owner'), e.message)
    locks.lock(n, owner)
    locks.unlock(n, owner)
    locks.lock(n, owner)
  end

  def test_lock_checks_job
    human = Baza::Humans.new(fake_pgsql).ensure(fake_name)
    token = human.tokens.add(fake_name)
    name = "#{fake_name}-a"
    job = token.start(name, fake_name, 1, 0, 'n/a', [], '192.168.1.1')
    assert(human.jobs.busy?(name))
    owner = "baza #{Baza::VERSION} #{Time.now.utc.iso8601}"
    assert_raises(Baza::Locks::Busy) do
      human.locks.lock(name, owner)
    end
    job.finish!(fake_name, 'stdout', 0, 544, 1, 0)
    human.locks.lock(name, owner)
    assert(human.locks.locked?(name))
  end
end
