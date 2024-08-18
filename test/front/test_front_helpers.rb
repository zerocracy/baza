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

class Baza::FrontHelpersTest < Minitest::Test
  include Baza::Helpers

  def test_large_text
    t = large_text('hello, world!')
    assert_equal(14, t.scan('span').count, t)
  end

  def test_html_tag
    assert_equal('<i>hello!</i>', html_tag('i') { 'hello!' })
    assert_equal('<i class="x">hello!</i>', html_tag('i', class: 'x') { 'hello!' })
    assert_equal('<i class="x" data="1">hello!</i>', html_tag('i', class: 'x', data: 1) { 'hello!' })
  end

  def test_bytes
    assert(bytes(42).include?('42B'))
    assert(bytes(42_000).include?('42kB'))
    assert(bytes(42_000_000).include?('42MB'))
  end

  def test_zents
    assert(zents(42_000).include?('+0.4200'))
    assert(zents(123_000).start_with?('<span class="good"'))
    assert(zents(-10_000).start_with?('<span class="bad"'))
  end

  def test_ago
    assert(ago(Time.now).start_with?('<span title='))
    assert(ago(Time.now - (5 * 60)).include?('5m0s ago'))
  end

  def test_secret
    assert(secret('swordfish').include?('<span>swor</span>'))
  end

  def test_secret_without_an_eye
    assert_equal('<span>swor</span><span class="gray">*****</span>', secret('swordfish', eye: false))
  end
end
