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

require 'faraday'

# The IP Geolocation client (https://ipgeolocation.io/)
class Baza::IpGeolocation
  def initialize(token:, connection: Faraday.new(url: 'https://api.ipgeolocation.io'))
    @token = token
    @connection = connection
  end

  def ipgeo(ip:)
    JSON.parse(@connection.get("ipgeo?apiKey=#{@token}&ip=#{ip}").body)
  end

  # Fake connection
  class FakeConnection
    def get(_url)
      Class.new do
        def self.body
          JSON.dump(
            {
              'ip' => '8.8.8.8',
              'continent_code' => 'NA',
              'continent_name' => 'North America',
              'country_code2' => 'US',
              'country_code3' => 'USA',
              'country_name' => 'United States',
              'country_name_official' => 'United States of America',
              'country_capital' => 'Washington, D.C.',
              'state_prov' => 'California',
              'state_code' => 'US-CA',
              'district' => '',
              'city' => 'Mountain View',
              'zipcode' => '94043-1351',
              'latitude' => '37.42240',
              'longitude' => '-122.08421',
              'is_eu' => false,
              'calling_code' => '+1',
              'country_tld' => '.us',
              'languages' => 'en-US,es-US,haw,fr',
              'country_flag' => 'https://ipgeolocation.io/static/flags/us_64.png',
              'geoname_id' => '6301403',
              'isp' => 'Google LLC',
              'connection_type' => '',
              'organization' => 'Google LLC',
              'country_emoji' => '🇺🇸',
              'currency' => { 'code' => 'USD', 'name' => 'US Dollar', 'symbol' => '$' },
              'time_zone' => {
                'name' => 'America/Los_Angeles',
                'offset' => -8,
                'offset_with_dst' => -7,
                'current_time' => '2024-09-03 07:42:32.209-0700',
                'current_time_unix' => 1_725_374_552.209,
                'is_dst' => true,
                'dst_savings' => 1,
                'dst_exists' => true,
                'dst_start' => {
                  'utc_time' => '2024-03-10 TIME 10',
                  'duration' => '+1H',
                  'gap' => true,
                  'dateTimeAfter' => '2024-03-10 TIME 03',
                  'dateTimeBefore' => '2024-03-10 TIME 02',
                  'overlap' => false
                },
                'dst_end' => {
                  'utc_time' => '2024-11-03 TIME 09',
                  'duration' => '-1H',
                  'gap' => false,
                  'dateTimeAfter' => '2024-11-03 TIME 01',
                  'dateTimeBefore' => '2024-11-03 TIME 02',
                  'overlap' => true
                }
              }
            }
          )
        end
      end
    end
  end
end
