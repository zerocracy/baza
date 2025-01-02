# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2025 Zerocracy
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

class Baza::SecretsInteractionTest < Baza::Test
  def test_adds_secret
    start_as_tester
    human = tester_human
    tokens = human.tokens
    token_name = fake_name
    token = tokens.add(token_name)

    secrets = human.secrets
    secrets.each.to_a.each do |s|
      secrets.remove(s[:id])
    end

    visit '/push'
    fill_in 'token', with: token.text
    job_name = fake_name
    fill_in 'name', with: job_name
    click_button 'Start'
    visit '/secrets'
    key = fake_name
    value = fake_name
    fill_in 'name', with: job_name
    fill_in 'key', with: key
    fill_in 'value', with: value
    click_button 'Add'

    assert_current_path '/secrets'
    assert page.has_text?(job_name)
    assert page.has_no_selector?('i[title="There is no job by this name, maybe a spelling error?"]')
    assert page.has_text?(key)
    assert page.has_text?(value[0..3])
  end

  def test_adds_secret_without_job
    start_as_tester
    visit '/secrets'
    job_name = fake_name
    key = fake_name
    value = fake_name
    fill_in 'name', with: job_name
    fill_in 'key', with: key
    fill_in 'value', with: value
    click_button 'Add'
    assert_current_path '/secrets'
    assert page.has_text?(job_name)
    assert page.has_selector?('i[title="There is no job by this name, maybe a spelling error?"]')
    assert page.has_text?(key)
    assert page.has_text?(value[0..3])
  end

  def test_removes_secret
    start_as_tester
    human = tester_human
    secrets = human.secrets
    secrets.each.to_a.each do |s|
      secrets.remove(s[:id])
    end
    n = fake_name
    k = fake_name
    v = fake_name * 10
    secrets.add(n, k, v)
    s = secrets.each.to_a.first
    visit "/secrets/#{s[:id]}/remove"
    assert secrets.each.to_a.empty?
  end
end
