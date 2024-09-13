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
require 'archive/zip'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class MainTest < Minitest::Test
  def test_one_record
    WebMock.disable_net_connect!
    Dir.mktmpdir do |home|
      FileUtils.mkdir_p(File.join(home, 'pack'))
      File.write(File.join(home, 'pack/job.json'), JSON.pretty_generate({ 'id' => 7 }))
      zip = File.join(home, 'pack.zip')
      Archive::Zip.archive(zip, File.join(home, 'pack/.'))
      rb = File.join(home, 'main.rb')
      File.write(
        rb,
        [
          Liquid::Template.parse(File.read(File.join(__dir__, '../../assets/lambda/main.rb'))).render(
            'swarm' => '42',
            'name' => 'swarmik',
            'secret' => 'sword-fish',
            'bucket' => 'foo',
            'region' => 'us-east-1',
            'account' => '424242'
          ),
          "
          go(
            event: {
              'Records' => [
                {
                  'messageId' => 'defd997b-4675-42fc-9f33-9457011de8b3',
                  'messageAttributes' => {
                    'job' => { 'stringValue' => '7' }
                  },
                  'body' => 'something funny...'
                }
              ]
            },
            context: nil
          )
          "
        ].join
      )
      stub_request(:put, 'http://169.254.169.254/latest/api/token').to_return(body: 'a-token')
      stub_request(:get, 'http://169.254.169.254/latest/meta-data/iam/security-credentials/').to_return(
        body: JSON.pretty_generate(
          {
            'AccessKeyId' => 'FAKEFAKEFAKEFAKEFAKE',
            'SecretAccessKey' => 'fakefakefakefakefakefakefakefakefakefake',
            'Token' => 'fake-fake-fake-fake-fake-fake-fake-fake'
          }
        )
      )
      stub_request(:get, 'http://169.254.169.254/latest/meta-data/iam/security-credentials/%7B').to_return(
        body: JSON.pretty_generate(
          {
            'AccessKeyId' => 'FAKEFAKEFAKEFAKEFAKE',
            'SecretAccessKey' => 'fakefakefakefakefakefakefakefakefakefake',
            'Token' => 'fake-fake-fake-fake-fake-fake-fake-fake'
          }
        )
      )
      stub_request(:put, 'http://swarms/42/invocation?code=0&job=7&secret=sword-fish')
      stub_request(:get, 'https://foo.s3.amazonaws.com/swarmik/7.zip').to_return(body: File.binread(zip))
      stub_request(:put, 'https://foo.s3.amazonaws.com/swarmik/7.zip')
      stub_request(:post, 'https://sqs.us-east-1.amazonaws.com/424242/baza-shift').to_return(
        body: JSON.pretty_generate(
          {
            'MD5OfMessageBody' => 'a951ef3c012387d2672814f5e050ad48',
            'MD5OfMessageAttributes' => '3a8a27b5b690247210a5e2297556f9b4'
          }
        )
      )
      load(rb)
    end
  end
end
