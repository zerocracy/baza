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
require 'factbase'
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
    skip # because now all pages are visible in testing mode
    pages = [
      '/sql', '/gift'
    ]
    login
    pages.each do |p|
      get(p)
      assert_status(303)
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

  def test_starts_job_via_post
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
    fb = Factbase.new
    fb.insert.foo = 'booom \x01\x02\x03'
    Tempfile.open do |f|
      File.binwrite(f.path, fb.export)
      post(
        '/push',
        'name' => test_name,
        'token' => token,
        'factbase' => Rack::Test::UploadedFile.new(f.path, 'application/zip')
      )
    end
    assert_status(302)
  end

  def test_starts_job_via_put
    uname = test_name
    login('yegor256')
    post('/gift', "human=#{uname}&zents=555555&summary=no")
    login(uname)
    get('/tokens')
    post('/tokens/add', 'name=foo')
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    get("/tokens/#{id}.json")
    token = JSON.parse(last_response.body)['text']
    fb = Factbase.new
    fb.insert.foo = 'booom \x01\x02\x03'
    header('X-Zerocracy-Token', token)
    name = test_name
    put("/push/#{name}", fb.export)
    assert_status(200)
    id = last_response.body.to_i
    assert(id.positive?)
    get("/jobs/#{id}")
    assert_status(200)
    get("/recent/#{name}.txt")
    assert_status(200)
    rid = last_response.body.to_i
    cycles = 0
    loop do
      get("/pull/#{rid}.fb")
      break if last_response.status == 200
      sleep 0.1
      cycles += 1
      break if cycles > 10
    end
    assert_status(200)
    get("/inspect/#{id}.fb")
    assert_status(200)
    fb.query('(always)').delete!
    fb.import(last_response.body)
    assert(fb.query('(exists foo)').each.to_a[0].foo.start_with?('booom'))
    get("/stdout/#{rid}.txt")
    assert_status(200)
  end

  private

  def assert_status(code)
    assert_equal(
      code, last_response.status,
      "#{last_request.url}:\n#{last_response.headers}\n#{last_response.body}"
    )
  end

  def login(name = test_name)
    enc = GLogin::Cookie::Open.new(
      { 'login' => name, 'id' => app.humans.ensure(name).id.to_s },
      ''
    ).to_s
    set_cookie("auth=#{enc}")
  end
end
