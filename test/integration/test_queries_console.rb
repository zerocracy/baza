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

class Baza::QueriesConsoleTest < Baza::Test
  def test_checks_that_query_field_is_filled_by_default
    start_as_tester
    visit '/sql'
    assert !find_field('query').value.nil?
  end

  def test_executes_query
    start_as_tester
    visit '/sql'
    fill_in 'query', with: 'SELECT * from human LIMIT 1'
    click_button 'Query'
    assert page.has_no_text?('Empty result.')
  end

  def test_executes_query_with_empty_result
    start_as_tester
    visit '/sql'
    fill_in 'query', with: "SELECT * from token WHERE human = #{tester_human.id} AND active LIMIT 1"
    click_button 'Query'
    assert page.has_text?('Empty result.')
  end
end
