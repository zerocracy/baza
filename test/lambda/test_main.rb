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
require 'archive/zip'
require 'random-port'
require 'shellwords'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class MainTest < Baza::Test
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
            'version' => '1.1.1',
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
              #{ENV['RACK_RUN'] ? '"quiet" => "true",' : ''}
              'Records' => [
                {
                  'messageId' => 'defd997b-4675-42fc-9f33-9457011de8b3',
                  'messageAttributes' => {
                    'job' => { 'stringValue' => '7' },
                    'more' => { 'stringValue' => '' },
                    'hops' => { 'stringValue' => '11' }
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
      stub_request(:put, %r{.*/invocation\?code=0&job=7&msec=[0-9]+&secret=sword-fish&version=1.1.1}).with do |req|
        assert_include(
          req.body,
          'A new event arrived, about job #7',
          'Incoming SQS event:',
          'job: "7"',
          'Loaded S3 object "swarmik/7.zip" (129 bytes) from bucket "foo"'
        )
        ''
      end
      stub_request(:get, 'https://foo.s3.amazonaws.com/swarmik/7.zip').to_return(body: File.binread(zip))
      stub_request(:put, 'https://foo.s3.amazonaws.com/swarmik/7.zip').with do |req|
        zip = File.join(home, 'result.zip')
        File.binwrite(zip, req.body)
        Baza::Zip.new(zip, loog: fake_loog).unpack(File.join(home, 'result'))
        assert(File.exist?(File.join(home, 'result/swarm-001-42-swarmik/stdout.txt')))
        ''
      end
      stub_request(:post, 'https://sqs.us-east-1.amazonaws.com/424242/baza-shift').to_return(
        body: JSON.pretty_generate(
          {
            'MD5OfMessageBody' => '8c2abe2dedea4b54103ab99e6ef3691d',
            'MD5OfMessageAttributes' => '1b6dbfa1fd638afc51b5705be5c1a9a0'
          }
        )
      )
      load(rb)
    end
  end

  def test_picks_up_trails
    fake_pgsql.exec('TRUNCATE job CASCADE')
    Dir.mktmpdir do |home|
      FileUtils.mkdir_p(File.join(home, 'swarm'))
      FileUtils.copy(File.join(__dir__, '../../assets/lambda/Gemfile'), home)
      File.write(
        File.join(home, 'main.rb'),
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
          def get_object(key, file, loog)
            Dir.mktmpdir do |home|
              File.write(
                File.join(home, 'job.json'),
                JSON.pretty_generate({'id' => 42})
              )
              Archive::Zip.archive(file, File.join(home, '/.'))
            end
          end
          def put_object(key, file, loog)
            FileUtils.copy(file, '/tmp/result.zip')
          end
          def send_message(id, more, hops, loog); end
          def report(stdout, code, msec, job); end
          go(
            event: {
              'Records' => [
                {
                  'messageId' => 'defd997b-4675-42fc-9f33-9457011de8b3',
                  'messageAttributes' => {
                    'job' => { 'stringValue' => '7' },
                    'hops' => { 'stringValue' => '5' }
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
      File.write(
        File.join(home, 'swarm/entry.sh'),
        "
        #!/bin/bash
        set -ex
        job=$1
        home=$2
        TRAILS_DIR=$( jq -r .options.TRAILS_DIR \"${home}/job.json\" )
        mkdir -p \"${TRAILS_DIR}/first\"
        echo 'first' > \"${TRAILS_DIR}/first/foo.txt\"
        echo 'first' > \"${TRAILS_DIR}/first/bar.txt\"
        mkdir -p \"${TRAILS_DIR}/second\"
        echo 'second' > \"${TRAILS_DIR}/second/hello.txt\"
        "
      )
      File.write(
        File.join(home, 'Dockerfile'),
        '
        FROM ruby:3.3
        WORKDIR /r
        RUN apt-get update -y && apt-get install -y jq unzip
        COPY Gemfile ./
        RUN bundle install
        COPY swarm/ /swarm
        COPY main.rb Gemfile ./
        '
      )
      stdout =
        fake_image(home) do |image|
          fake_container(
            image, '',
            "/bin/bash -c #{Shellwords.escape('ruby main.rb; unzip /tmp/result.zip -d /tmp/result')}"
          )
        end
      assert_include(
        stdout,
        'inflating: /tmp/result/swarm-001-42-swarmik/exit.txt',
        'inflating: /tmp/result/swarm-001-42-swarmik/stdout.txt',
        'inflating: /tmp/result/swarm-001-42-swarmik/trails/first/bar.txt',
        'inflating: /tmp/result/swarm-001-42-swarmik/trails/second/hello.txt',
        'Job processing finished'
      )
    end
  end

  def test_with_failure
    WebMock.disable_net_connect!
    fake_pgsql.exec('TRUNCATE job CASCADE')
    Dir.mktmpdir do |home|
      FileUtils.mkdir_p(File.join(home, 'swarm'))
      FileUtils.copy(File.join(__dir__, '../../assets/lambda/Gemfile'), home)
      File.write(
        File.join(home, 'main.rb'),
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
          def report(stdout, code, msec, job); puts 'Reported!'; end
          go(
            event: {
              'Records' => [
                {
                  'messageId' => 'defd997b-4675-42fc-9f33-9457011de8b3',
                  'messageAttributes' => {
                    'job' => { 'stringValue' => '7' },
                    'hops' => { 'stringValue' => '5' }
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
      File.write(
        File.join(home, 'Dockerfile'),
        '
        FROM ruby:3.3
        WORKDIR /r
        RUN apt-get update -y && apt-get install -y jq unzip
        COPY Gemfile ./
        RUN bundle install
        COPY swarm/ /swarm
        COPY main.rb Gemfile ./
        '
      )
      stdout =
        fake_image(home) do |image|
          fake_container(
            image, '',
            "/bin/bash -c #{Shellwords.escape('ruby main.rb')}"
          )
        end
      assert_include(stdout, 'Reported!')
    end
  end
end
