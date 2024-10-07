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
require 'factbase'
require 'w3c_validators'
require 'nokogiri'
require 'webmock/minitest'
require 'net/ping'
require_relative '../test__helper'
require_relative '../../baza'

class Baza::FrontBazaTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_w3c_validity
    skip unless Net::Ping::External.new('8.8.8.8').ping?
    pages = []
    get('/')
    assert_status(200)
    pages << last_response.body
    fake_login
    get('/dash')
    assert_status(200)
    pages << last_response.body
    pages.each do |html|
      xml =
        begin
          Nokogiri::XML.parse(html) do |c|
            c.norecover
            c.strict
          end
        rescue StandardError => e
          raise "#{html}\n\n#{e}"
        end
      assert(xml.errors.empty?, xml)
      assert(!xml.xpath('/html').empty?, xml)
      WebMock.enable_net_connect!
      v = W3CValidators::NuValidator.new.validate_text(html)
      assert(v.errors.empty?, "#{html}\n\n#{v.errors.join('; ')}")
    end
  end

  def test_all_daemons
    %w[gc verify tbot donations gc].each do |d|
      a = app.settings.send(d)
      s = a.to_s
      assert(s.end_with?('/0'), "#{d} (#{s}) fails with #{a.backtraces}")
    end
  end

  def test_renders_public_pages
    pages = [
      '/version',
      '/robots.txt',
      '/',
      '/svg/logo.svg',
      '/png/logo-white.png',
      '/css/main.css'
    ]
    pages.each do |p|
      get(p)
      assert_status(200)
    end
  end

  def test_renders_private_pages
    pages = [
      '/dash',
      '/tokens',
      '/jobs',
      '/locks',
      '/secrets',
      '/valves',
      '/account'
    ]
    fake_login
    pages.each do |p|
      get(p)
      assert_status(200)
    end
  end

  def test_creates_and_deletes_token
    fake_login
    get('/tokens')
    post('/tokens/add', 'name=foo')
    assert_status(302)
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    assert(id.positive?)
    get("/tokens/#{id}/deactivate")
    assert_status(302)
  end
end
