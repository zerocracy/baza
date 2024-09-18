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
require_relative '../../baza'

class Baza::FrontValvesTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_add
    fake_login
    post('/valves/add', 'name=hi&badge=abc&why=nothing')
    assert_status(302)
  end

  def test_reset
    n = fake_name
    fake_login(n)
    post('/valves/add', 'name=hi&badge=abc&why=nothing')
    assert_status(302)
    human = app.humans.ensure(n)
    id = human.valves.each.to_a.first[:id]
    post('/valves/reset', "id=#{id}&result=hello")
    assert_status(302)
    assert_equal('hello', human.valves.each.to_a.first[:result])
    post('/valves/reset', "id=#{id}&result=NIL")
    assert_status(302)
    assert_nil(human.valves.each.to_a.first[:result])
    post('/valves/reset', "id=#{id}&result=42")
    assert_status(302)
    assert_equal(42, human.valves.each.to_a.first[:result])
  end

  def test_valves
    uname = 'tester'
    fake_login(uname)
    get('/valves')
    assert_status(200)
    human = app.humans.ensure(uname)
    human.valves.enter('foo', 'boom', 'why', nil) do
      # nothing
    end
    get('/valves')
    assert_status(200)
  end

  def test_read_valve
    n = fake_name
    fake_login(n)
    human = app.humans.ensure(n)
    post('/valves/add', 'name=hi&badge=abc&why=nothing')
    get("/valves/#{human.valves.each.to_a.first[:id]}")
    assert_status(200)
  end
end
