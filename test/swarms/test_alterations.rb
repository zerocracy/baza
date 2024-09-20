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
require 'qbash'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2024 Yegor Bugayenko
# License:: MIT
class TestAlterations < Minitest::Test
  def test_simple_entry
    Dir.mktmpdir do |home|
      fb = Factbase.new
      File.binwrite(File.join(home, 'base.fb'), fb.export)
      File.write(File.join(home, 'alteration-42.rb'), '$fb.insert.foo = 42;')
      File.write(File.join(home, 'alteration-7.rb'), '$fb.insert.bar = 7;')
      qbash(
        "#{Shellwords.escape(File.join(__dir__, '../../swarms/alterations/entry.sh'))} 0 #{Shellwords.escape(home)}",
        loog: fake_loog
      )
      assert_include(
        File.read(File.join(home, 'alteration-42.txt')),
        '1 judge(s) processed'
      )
      fb.import(File.binread(File.join(home, 'base.fb')))
      assert_equal(1, fb.query('(eq foo 42)').each.to_a.size)
      assert_equal(1, fb.query('(eq bar 7)').each.to_a.size)
    end
  end
end
