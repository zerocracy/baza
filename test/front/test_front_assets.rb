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
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../baza'

class Baza::FrontPushTest < Baza::Test
  def app
    Sinatra::Application
  end

  def test_renders_css
    get('/css/main.css')
    assert_status(200)
    assert(last_response.body.include?('.logo'))
  end

  def test_renders_other_css
    %w[main front account alterations empty].each do |n|
      get("/css/#{n}.css")
      assert_status(200)
    end
  end

  def test_renders_markdown_pages
    %w[terms how-it-works].each do |p|
      get("/#{p}")
      assert_status(200)
      assert(last_response.body.include?('<h1>'))
    end
  end

  def test_returns_image_as_binary_data
    WebMock.disable_net_connect!
    body = SecureRandom.bytes(100)
    stub_request(:get, 'https://ipgeolocation.io/static/flags/us_64.png')
      .to_return(
        status: 200,
        body:
      )
    get('flag-of/8.8.8.8')
    assert_status(200)
    assert_equal('image/png', last_response.headers['Content-type'])
    assert_equal(body.bytes, last_response.body.bytes)
  end

  def test_404_when_ip_is_invalid
    WebMock.disable_net_connect!
    stub_request(:get, 'https://ipgeolocation.io/static/flags/us_64.png')
      .to_return(
        status: 200,
        body: SecureRandom.bytes(100)
      )
    get('flag-of/8.8.8')
    assert_status(404)
    get('flag-of/123')
    assert_status(404)
    get('flag-of/123.12')
    assert_status(404)
    get('flag-of/not-ip')
    assert_status(404)
  end

  def test_flag_is_cached
    WebMock.disable_net_connect!
    stub_request(:get, 'https://ipgeolocation.io/static/flags/us_64.png')
      .to_return(
        status: 200,
        body: SecureRandom.bytes(100)
      )
    ip = '8.8.8.8'
    img = 'https://ipgeolocation.io/static/flags/us_64.png'
    app.settings.zache.remove_all
    assert_empty(app.settings.zache)
    get("flag-of/#{ip}")
    assert_status(200)
    assert_equal(img, app.settings.zache.get("flag-of-#{ip}"))
  end
end
