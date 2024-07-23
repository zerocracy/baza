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

require_relative '../test__helper'

class Baza::DashTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_redirects_to_root
    visit '/dash'
    assert_equal '/', current_path
  end

  def test_clicks_on_start
    visit '/dash'
    assert page.has_link?('Start')
    click_link 'Start'
    assert_equal '/dash', current_path

    assert page.has_link?('Jobs')
    assert page.has_link?('Tokens')
    assert page.has_link?('Secrets')
    assert page.has_link?('Valves')
    assert page.has_link?('Account')
    assert page.has_link?('Locks')
    assert page.has_link?('Push')
    assert page.has_link?('SQL')
    assert page.has_link?('Gift')
    assert page.has_link?('Logout')
    assert page.has_link?('Terms')
  end

  def test_opens_jobs
    integration_login
    click_link 'Jobs'
    assert_equal '/jobs', current_path
  end

  def test_opens_tokens
    integration_login
    click_link 'Tokens'
    assert_equal '/tokens', current_path
  end

  def test_opens_secrets
    integration_login
    click_link 'Secrets'
    assert_equal '/secrets', current_path
  end

  def test_opens_valves
    integration_login
    click_link 'Valves'
    assert_equal '/valves', current_path
  end

  def test_opens_account
    integration_login
    click_link 'Account'
    assert_equal '/account', current_path
  end

  def test_opens_locks
    integration_login
    click_link 'Locks'
    assert_equal '/locks', current_path
  end

  def test_opens_push
    integration_login
    click_link 'Push'
    assert_equal '/push', current_path
  end

  def test_opens_sql
    integration_login
    click_link 'SQL'
    assert_equal '/sql', current_path
  end

  def test_opens_gift
    integration_login
    click_link 'Gift'
    assert_equal '/gift', current_path
  end

  def test_logouts
    integration_login
    click_link 'Logout'
    assert_equal '/', current_path
  end
end
