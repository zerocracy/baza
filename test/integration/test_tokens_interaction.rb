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

class Baza::TokensInteractionTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_adds_token
    integration_login
    click_link 'Tokens'
    token_name = 'hello'
    fill_in 'Unique token name', with: token_name
    click_button 'Add'
    assert page.has_content?(token_name)
    page.has_text?(/New token #\d+ added/)
  end

  def test_does_not_add_repetitive_token
    integration_login
    click_link 'Tokens'
    token_name = 'token'
    fill_in 'Unique token name', with: token_name
    click_button 'Add'
    assert page.has_content?(token_name)
    page.has_text?(/New token #\d+ added/)

    fill_in 'Unique token name', with: token_name
    click_button 'Add'
    assert_current_path '/dash'
  end

  def test_does_not_add_token_with_invalid_name
    integration_login
    click_link 'Tokens'
    token_name = '12345'
    fill_in 'Unique token name', with: token_name
    click_button 'Add'
    assert_current_path '/dash'
  end

  def test_deactivates_token
    human = Baza::Humans.new(fake_pgsql).ensure(fake_name)
    tokens = human.tokens
    name = fake_name
    assert_equal(0, tokens.size)
    token = tokens.add(name)
    assert(token.active?)
    integration_login
    visit "/tokens/#{token.id}/deactivate"
    page.has_text?("##{token.id}")
    tokens.get(token.id)
    assert(!token.active?)
  end
end
