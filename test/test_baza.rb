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
require 'rack/test'
require_relative 'test__helper'
require_relative '../objects/baza'
require_relative '../baza'

module Rack
  module Test
    class Session
      def default_env
        { 'REMOTE_ADDR' => '127.0.0.1', 'HTTPS' => 'on' }.merge(headers_for_env)
      end
    end
  end
end

class Baza::AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
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
      '/account'
    ]
    login
    pages.each do |p|
      get(p)
      assert_status(200)
    end
  end

  def test_not_found
    pages = [
      '/unknown_path',
      '/js/x/y/z/not-found.js',
      '/svg/not-found.svg',
      '/png/a/b/cdd/not-found.png',
      '/css/a/b/c/not-found.css'
    ]
    pages.each do |p|
      get(p)
      assert_status(404)
      assert_equal('text/html;charset=utf-8', last_response.content_type)
    end
  end

  def test_protected_pages
    pages = [
      '/sql', '/push', '/gift',
      '/dash', '/tokens', '/jobs', '/account'
    ]
    pages.each do |p|
      get(p)
      assert_status(302)
    end
  end

  def test_non_admin_pages
    pages = [
      '/sql', '/gift'
    ]
    login
    pages.each do |p|
      get(p)
      assert_status(302)
    end
  end

  def test_renders_admin_pages
    pages = [
      '/sql',
      '/gift'
    ]
    login('yegor256')
    pages.each do |p|
      get(p)
      assert_status(200)
    end
  end

  def test_creates_and_deletes_token
    login
    get('/tokens')
    post('/tokens/add', 'name=foo')
    assert_status(302)
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    assert(id.positive?)
    get("/tokens/#{id}/deactivate")
    assert_status(302)
  end

  def test_starts_job
    uname = test_name
    login('yegor256')
    post('/gift', "human=#{uname}&zents=9999&summary=no")
    login(uname)
    get('/tokens')
    post('/tokens/add', 'name=foo')
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    get("/tokens/#{id}.json")
    token = JSON.parse(last_response.body)['text']
    get('/push')
    Tempfile.open do |f|
      File.write(f.path, 'booom')
      post(
        '/push',
        'token' => token,
        'factbase' => Rack::Test::UploadedFile.new(f.path, 'application/zip')
      )
    end
    assert_status(302)
    id = last_response.headers['X-Zerocracy-JobId'].to_i
    assert(id.positive?)
    get("/jobs/#{id}")
    assert_status(200)
  end

  private

  def assert_status(code)
    assert_equal(code, last_response.status, "#{last_request.url}:\n#{last_response.body}")
  end

  def login(name = test_name)
    enc = GLogin::Cookie::Open.new(
      { 'id' => name, 'login' => name },
      ''
    ).to_s
    set_cookie("identity=#{enc}")
  end
end
