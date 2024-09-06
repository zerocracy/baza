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
require_relative '../../baza'

class Baza::FrontFlagOfTest < Minitest::Test
  def app
    Sinatra::Application
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

  def test_path_to_flag_is_cached
    ip = '8.8.8.8'
    img = 'https://ipgeolocation.io/static/flags/us_64.png'
    app.settings.ipgeolocation_cache.remove_all
    assert_empty(app.settings.ipgeolocation_cache)
    assert_includes(path_to_flag(ip, app.settings), img)
    assert_equal(img, app.settings.ipgeolocation_cache.get(ip))
    assert_includes(path_to_flag(ip, app.settings), app.settings.ipgeolocation_cache.get(ip))
  end
end
