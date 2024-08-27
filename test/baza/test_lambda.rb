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
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/zip'
require_relative '../../objects/baza/lambda'

# Test for Lambda.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::LambdaTest < Minitest::Test
  def test_live_deploy
    WebMock.disable_net_connect!
    fake_pgsql.exec('DELETE FROM swarm')
    fake_human.swarms.add(fake_name, 'zerocracy/j', 'master')
    stub('RunInstances', { instancesSet: { item: { instanceId: 'i-42' } } })
    stub('TerminateInstances', {})
    stub('DescribeInstanceStatus', { instanceStatusSet: { item: { instanceStatus: { status: 'ok' } } } })
    stub('DescribeInstances', { reservationSet: { item: { instancesSet: { item: { ipAddress: '127.0.0.1' } } } } })
    Dir.mktmpdir do |home|
      keys = File.join(home, 'authorized_keys')
      docker_log = File.join(home, 'docker.log')
      File.write(keys, 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKqkTbKGd7ZHNJDFeVN/jwcAu+SFTt2bOdpc7njTXpWUxrq58b3KRrXkTToCTAN2Xz8ClBZ7fLHPvYnh89HBoYRFQxXXzUGLbwhVwRnF5THlPmwJpTyk22W1EeMC3P8bcERCyDAsqD7wbQTcZ8B4QtYAx3Oudr9UWBCABqM+WaAMjhTQOq9bGhuu2VXUztH7Z1caZHavWVlOrhils/jyXD+HYX9S8POu1ybf9VwAZfzyIKG7BOhLtcnxh4lh+mtJX7qwkaoSpSJNWWoQRK2YdPGRQCwIqHkxsgTBsPPp3SSLfJEuLwTyHbDe0vtOn7wS2PlE1DQvG39kheXo/Lwz6F yb@yb.local')
      `docker run -d -p 2222:22 -v '#{keys}:/etc/authorized_keys/tester' -e SSH_USERS="tester:1001:1001" --name=fakeserver kabirbaidhya/fakeserver 2>&1 >#{docker_log}`
      container = File.read(docker_log).split("\n").last.strip
      begin
        zip = File.join(home, 'image.zip')
        Baza::Lambda.new(
          fake_humans,
          'AKI..............XKU', # AWS key
          'KmX8................................eUnE', # AWS secret
          'us-east-1', # EC2 region
          'sg-0ffb4444444440ed3', # EC2 security group
          'subnet-0f8044444444e041e', # EC2 subnet
          'ami-0187844444444301d', # EC2 image
           # EC2 SSH private key
          '-----BEGIN RSA PRIVATE KEY-----
          MIIEpAIBAAKCAQEAyqpE2yhne2RzSQxXlTf48HALvkhU7dmznaXO54016VlMa6uf
          G9yka15E06AkwDdl8/ApQWe3yxz72J4fPRwaGERUMV181Bi28IVcEZxeUx5T5sCa
          U8pNtltRHjAtz/G3BEQsgwLKg+8G0E3GfAeELWAMdzrna/VFgQgAajPlmgDI4U0D
          qvWxobrtlV1M7R+2dXGmR2r1lZTq4YpbP48lw/h2F/UvDzrtcm3/VcAGX88iChuw
          ToS7XJ8YeJYfprSV+6sJGqEqUiTVlqEEStmHTxkUAsCKh5MbIEwbDz6d0ki3yRLi
          8E8h2w3tL7Tp+8Etj5RNQ0Lxt/ZIXl6Py8M+hQIDAQABAoIBAD5Ud7DfkFQG5N4G
          ibk+6bUpALOZE2XDmtZVdHkKmRYXfMVwlxK+nWLYL1rW2fa0EwsfRdDz0TcKxvos
          R3dH+U6VVT+JfSbOIxV+Ln7MFMaDgVJq0gwLIDOBikU6lBxsPtl1DiuM5DQHg5T1
          FqJ2vVQnQi45U4uEd8fjah0/sNHX91GpME4BVB4lhQAO33C+LXhtmQlph5e+GIg6
          JjKCxjjSZjkLgHr1Bqt03qFhYCedMpS8UJLB/zGvqHSogM01UCv7/mGmk9Jp8mcz
          /ekrtEAs2bxko6UWGSYam6/XI049/ulAftV4f4nJEfK66HoOoxBHc8enKxvPUEf8
          Ut52oIECgYEA+BQrEj0yCEf35jTbpoHsYkgdUeL93Z1+4SOwGSqCJ1w8dcHgxqFf
          6GSgtsxMCjOha2KZ6CINxai+EHHhPmrZDz7j4OePTzVkMRCnzVcXaD7rJoRS0Fke
          B6LsVm7CAVlXo8dnmCGuhfHcTmRwpgHb1ANf3GLL/O2y1/jLGG6IIl0CgYEA0SLi
          Acw9DjPkau6oKmlm3dJ0EDnr8BJuiN+0YOll5BgQ9RCb7tMWl4PTJmtGjAlCXNwN
          UrosqPE2tcVcXHZBRMcWyYgAXFgrn/y44gtci+/nsVOSJy8yfq7cKeYATiqV+PAM
          OYJHIX7nmkZnbomUgb9IDOgMO7merm/hqvIEGkkCgYEA602l9OzakgRBXLdySCMf
          5bDlLpCRny0N9dp148jwHwlbx44X+A+E+tbHodtxnJOQXlzuAsKaMYt2i/6YWS3b
          qJxMZTz+L3FDEU7s+tXKu/RB8wy7yCdfVnrwlKMFnWXyvMQcvK3l7eKUxj56ottM
          eXKh8FY9ijCj3Dp92TSuJ3kCgYEAmJSAm5ssuF33umRgYIEBwbi3YNdBYaew6T98
          1G+0HNPKG2GAwp9TDjvpI1CE6coflqwdNEwMJT3HEprpJbRJLiqqX2JQEQ9q1JCH
          OrPbU2U2ftNgACKZDn/4tMDPXDgJrtNDt/lqd++kfZP8BlNt+7NYl8H8mt5z/QQ3
          eoaTo7ECgYBl1HpMPpdGuiu6zPu6u4oD4UTE4R4lpMHLVh55KPZ+s39yRlZFCz+q
          9VzsLtGNCzE0jXP/MIHAxqo8RYoVK49wS+I0cGXe6jKEftJJDNOhiZqhB/OaFj/W
          Pj1tA1+lww+nyLM1mw6zIFsnHrQZfKI5MO6wGyU9w8Ao6OAvRHgcHQ==
          -----END RSA PRIVATE KEY-----',
          loog: Loog::VERBOSE,
          user: 'tester', port: 2222
        ).deploy
      ensure
        `docker rm -f #{container}`
      end
    end
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
    end.join('')
  end
end
