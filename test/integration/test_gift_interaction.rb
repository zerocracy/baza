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

class Baza::GiftInteractionTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_adds_positive_gift
    start_as_tester
    visit '/gift'
    assert_equal 'tester', find_field('human').value
    zents = 100_000
    summary = fake_name
    fill_in 'zents', with: zents
    fill_in 'summary', with: summary
    click_button 'Add'
    assert_current_path '/account'
    assert page.has_text?(summary)
    assert page.has_text?("+#{format('%.4f', zents / 100_000)}")
  end

  def test_adds_negative_gift
    start_as_tester
    visit '/gift'
    assert_equal 'tester', find_field('human').value
    zents = -100_000
    summary = fake_name
    fill_in 'zents', with: zents
    fill_in 'summary', with: summary
    click_button 'Add'
    assert_current_path '/account'
    assert page.has_text?(summary)
    assert page.has_text?(format('%.4f', zents / 100_000).to_s)
  end

  def test_does_not_add_gift_with_empty_human
    start_as_tester
    visit '/gift'
    zents = 200_000
    summary = fake_name
    fill_in 'human', with: ''
    fill_in 'zents', with: zents
    fill_in 'summary', with: summary
    click_button 'Add'
    assert_current_path '/gift'
    visit '/account'
    assert !page.has_text?(summary)
    assert !page.has_text?("+#{format('%.4f', zents / 100_000)}")
  end

  def test_add_gift_to_other_human
    start_as_tester
    human_name = fake_name
    Baza::Humans.new(fake_pgsql).ensure(human_name)
    visit '/gift'
    zents = 200_000
    summary = fake_name
    fill_in 'human', with: human_name
    fill_in 'zents', with: zents
    fill_in 'summary', with: summary
    click_button 'Add'
    assert_current_path '/account'
    assert !page.has_text?(summary)
    assert !page.has_text?("+#{format('%.4f', zents / 100_000)}")
  end
end
