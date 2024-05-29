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
require 'loog'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/factbases'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::FactbasesTest < Minitest::Test
  def test_fake_usage
    fbs = Baza::Factbases.new('', '')
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'a.fb')
      File.write(input, 'hey')
      uuid = fbs.save(input)
      output = File.join(dir, 'b.fb')
      fbs.load(uuid, output)
      assert_equal('hey', File.read(output))
      fbs.delete(uuid)
    end
  end

  def test_aws_usage
    skip
    fbs = Baza::Factbases.new('AKIAQJE...', 'KmX8eM...', loog: Loog::NULL)
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'a.fb')
      File.write(input, 'hey')
      uuid = fbs.save(input)
      output = File.join(dir, 'b.fb')
      fbs.load(uuid, output)
      assert_equal('hey', File.read(output))
    end
  end
end
