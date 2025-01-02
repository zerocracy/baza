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

require 'minitest/autorun'
require 'factbase'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/errors'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::ErrorsTest < Baza::Test
  def test_counting
    Tempfile.open do |f|
      fb = Factbase.new
      s = fb.insert
      s.what = 'judges-summary'
      s.error = 'oops, failed'
      s.error = 'second failure'
      File.binwrite(f, fb.export)
      assert_equal(2, Baza::Errors.new(f).count)
    end
  end

  def test_listing
    Tempfile.open do |f|
      fb = Factbase.new
      s = fb.insert
      s.what = 'judges-summary'
      s.error = 'oops, failed'
      s.error = 'second failure'
      File.binwrite(f, fb.export)
      assert_equal('oops, failed', Baza::Errors.new(f).to_a.first)
    end
  end

  def test_counting_no_summary
    Tempfile.open do |f|
      fb = Factbase.new
      File.binwrite(f, fb.export)
      assert_equal(0, Baza::Errors.new(f).count)
    end
  end

  def test_counting_no_errors
    Tempfile.open do |f|
      fb = Factbase.new
      s = fb.insert
      s.what = 'judges-summary'
      File.binwrite(f, fb.export)
      assert_equal(0, Baza::Errors.new(f).count)
    end
  end
end
