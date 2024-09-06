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
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../../baza'

class Baza::AlwaysReleaseTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_simple
    WebMock.disable_net_connect!
    app.set :config, {
      'lambda' => {
        'account' => '42424242',
        'key' => 'FAKEFAKEFAKEFAKEFAKE',
        'secret' => 'fakefakefakefakefakefakefakefakefakefake',
        'region' => 'us-east-1',
        'sgroup' => 'sg-424242',
        'subnet' => 'sn-42424242',
        'image' => 't2.large',
        'id_rsa' => ''
      }
    }
    fake_aws('RunInstances', { instancesSet: { item: { instanceId: 'i-58585858' } } })
    fake_human.swarms.add(fake_name, "zerocracy/#{fake_name}", 'master', '/')
    load(File.join(__dir__, '../../always/always_release.rb'))
  end
end
