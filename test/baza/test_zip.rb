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
require 'fileutils'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/zip'

# Test for Zip.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::ZipTest < Baza::Test
  def test_packs_and_unpacks
    Dir.mktmpdir do |home|
      zip = File.join(home, 'foo.zip')
      path = 'a/b/c/.test.txt'
      Dir.mktmpdir do |dir|
        txt = File.join(dir, path)
        FileUtils.mkdir_p(File.dirname(txt))
        File.write(txt, 'hello, world!')
        Baza::Zip.new(zip).pack(dir)
      end
      assert(File.exist?(zip))
      assert_equal(4, Baza::Zip.new(zip).entries.size)
      Dir.mktmpdir do |dir|
        Baza::Zip.new(zip).unpack(dir)
        txt = File.join(dir, path)
        assert(File.exist?(txt))
      end
    end
  end
end
