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
require 'iri'
require_relative '../test__helper'
require_relative '../../baza'

class Baza::FrontErrorsTest < Baza::Test
  def app
    Sinatra::Application
  end

  def test_not_found
    pages = [
      '/unknown_path',
      '/js/x/y/z/not-found.js',
      '/svg/not-found.svg',
      '/png/a/b/cdd/not-found.png',
      '/css/a/b/c/not-found.css'
    ]
    pages.each do |p|
      get(p)
      assert_status(404)
      assert_equal('text/html;charset=utf-8', last_response.content_type)
    end
  end

  def test_fatal_error
    get(Iri.new('/error').add(m: "\u0000;\n\t\t\r\nhello").to_s)
    assert_status(503)
    assert(last_response.body.include?('hello'))
    assert(last_response.headers['X-Zerocracy-Failure'].include?('hello'))
  end

  def test_protected_pages
    pages = [
      '/sql', '/push', '/gift',
      '/dash', '/tokens', '/jobs', '/account'
    ]
    pages.each do |p|
      get(p)
      assert_status(303)
    end
  end

  def test_non_admin_pages
    pages = [
      '/sql',
      '/gift',
      '/footer/status?badge=gc',
      '/footer/status?badge=pipeline',
      '/footer/status?badge=donations'
    ]
    fake_login('yegor256')
    pages.each do |p|
      get(p)
      assert_status(200)
    end
  end
end
