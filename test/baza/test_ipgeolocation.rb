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
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/ipgeolocation'

# Test for IpGeolocation.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::IpGeolocationTest < Minitest::Test
  def test_create_client
    client = Baza::IpGeolocation.new(token: 'token', connection: Faraday.new(url: Baza::IpGeolocation.host))
    assert_instance_of(Baza::IpGeolocation, client)
  end

  def test_call_fake_ipgeo
    client = Baza::IpGeolocation.new(token: 'token', connection: Baza::IpGeolocation::FakeConnection.new)
    assert_instance_of(Baza::IpGeolocation, client)
    result = client.ipgeo(ip: '8.8.8.8')
    assert_equal('8.8.8.8', result['ip'])
    assert_equal('United States', result['country_name'])
    assert_equal('https://ipgeolocation.io/static/flags/us_64.png', result['country_flag'])
  end

  def test_call_ipgeo
    skip # it's a "live" test, run it manually if you need it
    WebMock.allow_net_connect!
    client = Baza::IpGeolocation.new(
      token: ENV.fetch('IPGEOLOCATION_TOKEN', nil),
      connection: Faraday.new(url: Baza::IpGeolocation.host)
    )
    result = client.ipgeo(ip: '8.8.8.8')
    assert_equal('8.8.8.8', result['ip'])
    assert_equal('United States', result['country_name'])
    assert_equal('https://ipgeolocation.io/static/flags/us_64.png', result['country_flag'])
  end

  def test_call_ipgeo_with_invalid_token
    skip # it's a "live" test, run it manually if you need it
    WebMock.allow_net_connect!
    client = Baza::IpGeolocation.new(token: nil, connection: Faraday.new(url: Baza::IpGeolocation.host))
    result = client.ipgeo(ip: '8.8.8.8')
    assert_match(/Please provide an API key/, result['message'])
  end
end
