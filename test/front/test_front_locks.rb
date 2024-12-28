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
require_relative '../../baza'

class Baza::FrontLocksTest < Baza::Test
  def app
    Sinatra::Application
  end

  def test_lock_unlock
    fake_login(fake_name)
    name = fake_name
    owner = fake_name
    get("/lock/#{name}?owner=#{owner}")
    assert_status(302)
    get("/unlock/#{name}?owner=#{owner}")
    assert_status(302)
    get("/lock/#{name}?owner=#{fake_name}")
    assert_status(302)
    get('/locks')
    assert_status(200)
  end

  def test_relock_failure
    fake_login(fake_name)
    name = fake_name
    get("/lock/#{name}?owner=first")
    assert_status(302)
    get("/lock/#{name}?owner=first")
    assert_status(302)
    get("/lock/#{name}?owner=second")
    assert_status(409)
  end
end
