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
require 'fileutils'
require 'loog'
require 'yaml'
require 'webmock/minitest'
require 'net/ssh'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/zip'
require_relative '../../objects/baza/lambda'

# Test for Lambda.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::LambdaTest < Minitest::Test
  def test_fake_deploy
    WebMock.disable_net_connect!
    loog = Loog::VERBOSE
    fake_pgsql.exec('DELETE FROM swarm')
    fake_human.swarms.add('j', 'zerocracy/j', 'master')
    stub('RunInstances', { instancesSet: { item: { instanceId: 'i-42424242' } } })
    stub('TerminateInstances', {})
    stub('DescribeInstanceStatus', { instanceStatusSet: { item: { instanceStatus: { status: 'ok' } } } })
    stub('DescribeInstances', { reservationSet: { item: { instancesSet: { item: { ipAddress: '127.0.0.1' } } } } })
    Dir.mktmpdir do |home|
      id_rsa = File.join(home, 'id_rsa')
      FileUtils.copy(File.join(__dir__, '../../fixtures/ssh/id_rsa'), id_rsa)
      id_rsa_pub = File.join(home, 'id_rsa.pub')
      FileUtils.copy(File.join(__dir__, '../../fixtures/ssh/id_rsa.pub'), id_rsa_pub)
      user = 'tester'
      port = 2222
      docker_log = File.join(home, 'docker.log')
      loog.debug(%x[
        docker run -d -p #{port}:22 \
        -v '#{id_rsa_pub}:/etc/authorized_keys/#{user}' \
        -e SSH_USERS="#{user}:1001:1001" \
        --name=fakeserver \
        kabirbaidhya/fakeserver 2>&1 >#{docker_log}
      ])
      assert_equal(0, $CHILD_STATUS.exitstatus)
      container = File.read(docker_log).split("\n").last.strip
      begin
        Net::SSH.start('127.0.0.1', user, port: when_ready(port), keys: [], key_data: [File.read(id_rsa)], keys_only: true) do |ssh|
          ssh.exec!(
            [
              '(',
              'echo "echo fake-\$0 \$@" > docker',
              '&& echo "echo fake-\$0 \$@" > aws',
              '&& chmod a+x docker aws',
              ') 2>&1'
            ].join
          )
        end
        Baza::Lambda.new(
          fake_humans,
          # AWS account ID
          '44444444444',
          # AWS key
          'AKIAthisisfakekeyXXX',
          # AWS secret
          'KmX8thisisfakesecret/thisisfakeeXXXXXXXX',
          # EC2 region
          'us-east-1',
          # EC2 security group
          'sg-44444444444444444',
          # EC2 subnet
          'subnet-44444444444444444',
          # EC2 image
          'ami-44444444444444444',
          File.read(id_rsa),
          loog:, user:, port:
        ).deploy
      ensure
        `docker rm -f #{container}`
      end
    end
  end

  def test_live_deploy
    fake_pgsql.exec('DELETE FROM swarm')
    yml = '/code/home/assets/zerocracy/baza.yml'
    skip unless File.exist?(yml)
    cfg = YAML.safe_load(File.open(yml))['lambda']
    fake_human.swarms.add(fake_name, "#{fake_name}/#{fake_name}", fake_name).dirty!(true)
    WebMock.enable_net_connect!
    Baza::Lambda.new(
      fake_humans,
      cfg['account'],
      cfg['key'],
      cfg['secret'],
      cfg['region'],
      cfg['sgroup'],
      cfg['subnet'],
      cfg['image'],
      cfg['ssh'],
      loog: Loog::VERBOSE
    ).deploy
  end

  private

  def stub(cmd, hash)
    xml = "<#{cmd}Response>#{to_xml(hash)}</#{cmd}Response>"
    stub_request(:post, 'https://ec2.us-east-1.amazonaws.com/')
      .with(body: /#{cmd}/)
      .to_return(body: xml)
  end

  def to_xml(hash)
    hash.map do |k, v|
      "<#{k}>#{v.is_a?(Hash) ? to_xml(v) : v}</#{k}>"
    end.join
  end

  def when_ready(port)
    sleep 1
    port
  end
end
