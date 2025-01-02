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
require 'webmock/minitest'
require 'loog'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/sqs'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::SQSTest < Baza::Test
  def test_fake_usage
    sqs = Baza::SQS.new('', '', '')
    sqs.push(42, 'hello')
  end

  def test_live_aws_usage
    skip
    WebMock.enable_net_connect!
    sqs = Baza::SQS.new('AKIA...', 'KmX8e...', 'https://sqs.us-east-1.amazonaws.com/...', loog: fake_loog)
    sqs.push(42, 'testing!')
  end
end
