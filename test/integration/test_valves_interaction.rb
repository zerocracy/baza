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

class Baza::ValvesInteractionTest < Baza::Test
  def test_adds_valve
    start_as_tester
    human = tester_human
    tokens = human.tokens
    token_name = fake_name
    token = tokens.add(token_name)

    valves = human.valves
    valves.each.to_a.each do |v|
      valves.remove(v[:id])
    end

    visit '/push'
    fill_in 'token', with: token.text
    job_name = fake_name
    fill_in 'name', with: job_name
    click_button 'Start'
    visit '/valves'
    badge = fake_name
    result = fake_name
    why = fake_name
    fill_in 'name', with: job_name
    fill_in 'badge', with: badge
    fill_in 'result', with: result
    fill_in 'why', with: why
    click_button 'Add'

    assert_current_path '/valves'
    assert page.has_text?(job_name)
    assert page.has_no_selector?('i[title="There is no job by this name, maybe a spelling error?"]')
    assert page.has_text?(badge)
    assert page.has_text?(result)
  end

  def test_adds_valve_without_job
    start_as_tester
    visit '/valves'
    job_name = fake_name
    badge = fake_name
    result = fake_name
    why = fake_name
    fill_in 'name', with: job_name
    fill_in 'badge', with: badge
    fill_in 'result', with: result
    fill_in 'why', with: why
    click_button 'Add'
    assert_current_path '/valves'
    assert page.has_text?(job_name)
    assert page.has_selector?('i[title="There is no job by this name, maybe a spelling error?"]')
    assert page.has_text?(badge)
    assert page.has_text?(result)
  end

  def test_removes_valve
    start_as_tester
    human = tester_human
    valves = human.valves
    valves.each.to_a.each do |s|
      valves.remove(s[:id])
    end
    n = fake_name
    b = fake_name
    valves.enter(n, b, 'why', nil) { 42 }
    v = valves.each.to_a.first
    visit "/valves/#{v[:id]}/remove"
    assert valves.empty?
  end
end
