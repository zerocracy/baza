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
require 'base64'
require 'zlib'
require 'wait_for'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../baza'

class Baza::FrontPushTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_starts_job_via_post
    uname = fake_name
    login('yegor256')
    post('/gift', "human=#{uname}&zents=9999&summary=no")
    login(uname)
    get('/tokens')
    post('/tokens/add', 'name=foo')
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    get("/tokens/#{id}.json")
    token = JSON.parse(last_response.body)['text']
    get('/push')
    header('User-Agent', 'something')
    post('/push', 'name' => fake_name, 'token' => token)
    assert_status(302)
    fb = Factbase.new
    fb.insert.foo = 'booom \x01\x02\x03'
    assert_status(302)
    Tempfile.open do |f|
      File.binwrite(f.path, fb.export)
      post(
        '/push',
        'name' => fake_name,
        'token' => token,
        'factbase' => Rack::Test::UploadedFile.new(f.path, 'application/zip')
      )
    end
    assert_status(302)
  end

  def test_rejects_file_upload
    uname = fake_name
    login('yegor256')
    post('/gift', "human=#{uname}&zents=9999&summary=no")
    login(uname)
    get('/tokens')
    post('/tokens/add', 'name=foo')
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    get("/tokens/#{id}.json")
    token = JSON.parse(last_response.body)['text']
    get('/push')
    post('/push', 'name' => fake_name, 'token' => token)
    assert_status(303)
    fb = Factbase.new
    fb.insert.foo = 'a' * (11 * 1024 * 1024)
    Tempfile.open do |f|
      File.binwrite(f.path, fb.export)
      post(
        '/push',
        'name' => fake_name,
        'token' => token,
        'factbase' => Rack::Test::UploadedFile.new(f.path, 'application/zip')
      )
    end
    assert_status(303)
  end

  def test_pushes_gzip_file
    uname = fake_name
    login('yegor256')
    post('/gift', "human=#{uname}&zents=9999&summary=no")
    login(uname)
    get('/tokens')
    post('/tokens/add', 'name=foo')
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    get("/tokens/#{id}.json")
    token = JSON.parse(last_response.body)['text']
    get('/push')
    header('User-Agent', 'something')

    fb = Factbase.new
    fb.insert.foo = 'booom \x01\x02\x03'
    Tempfile.open do |f|
      Zlib::GzipWriter.open(f.path) do |gz|
        gz.write fb.export
      end
      header('Content-Encoding', 'gzip')
      post(
        '/push',
        'name' => fake_name,
        'token' => token,
        'factbase' => Rack::Test::UploadedFile.new(f.path, 'application/gzip')
      )
    end
    assert_status(302)
  end

  def test_rejects_broken_file_format
    token = make_valid_token
    header('X-Zerocracy-Token', token)
    header('User-Agent', 'something')
    put("/push/#{fake_name}", 'some broken content')
    assert_status(303)
  end

  def test_starts_job_via_put
    app.settings.pipeline.start(0)
    token = make_valid_token
    fb = Factbase.new
    (0..100).each do |i|
      fb.insert.foo = "booom \x01\x02\x03 #{i}"
    end
    header('X-Zerocracy-Token', token)
    header('User-Agent', 'something')
    header(
      'X-Zerocracy-Meta',
      [
        Base64.encode64('vitals_url:https://zerocracy.com'),
        Base64.encode64('how are you, друг?')
      ].join('  ')
    )
    name = fake_name
    put("/push/#{name}", fb.export)
    assert_status(200)
    id = last_response.body.to_i
    assert(id.positive?)
    get('/jobs')
    assert_status(200)
    get("/jobs/#{id}")
    assert_status(200)
    get("/jobs/#{id}/input.html")
    assert_status(200)
    get("/recent/#{name}.txt")
    assert_status(200)
    rid = last_response.body.to_i
    wait_for(10) do
      get("/finished/#{rid}")
      assert_status(200)
      last_response.body == 'yes'
    end
    stdout = get("/stdout/#{rid}.txt").body
    assert_status(200)
    assert(stdout.include?('HOW ARE YOU, ДРУГ'), stdout)
    code = get("/exit/#{rid}.txt").body
    assert_status(200)
    assert_equal('0', code)
    get("/pull/#{rid}.fb")
    assert_status(200)
    get("/inspect/#{id}.fb")
    assert_status(200)
    fb.query('(always)').delete!
    fb.import(last_response.body)
    assert(fb.query('(exists foo)').each.to_a[0].foo.start_with?('booom'))
    get("/jobs/#{id}/output.html")
    assert_status(200)
    get("/jobs/#{rid}/expire")
    assert_status(302)
    app.settings.pipeline.stop
  end

  def test_pushes_gzipped_file_via_put
    token = make_valid_token
    fb = Factbase.new
    (0..100).each do |i|
      fb.insert.foo = "booom \x01\x02\x03 #{i}"
    end
    header('X-Zerocracy-Token', token)
    header('User-Agent', 'something')
    header('Content-Encoding', 'gzip')
    header('Content-Type', 'application/zip')
    header(
      'X-Zerocracy-Meta',
      [
        Base64.encode64('vitals_url:https://zerocracy.com'),
        Base64.encode64('how are you, друг?')
      ].join('  ')
    )
    name = fake_name
    payload = ''.dup
    gz = Zlib::GzipWriter.new(StringIO.new(payload))
    gz.write(fb.export)
    gz.close
    put("/push/#{name}", payload)
    assert_status(200)
  end

  def test_rejects_duplicate_puts
    token = make_valid_token
    fb = Factbase.new
    fb.insert.foo = 42
    header('X-Zerocracy-Token', token)
    name = fake_name
    header('User-Agent', 'something')
    put("/push/#{name}", fb.export)
    assert_status(200)
    header('User-Agent', 'something')
    put("/push/#{name}", fb.export)
    assert_status(303)
  end

  def test_sends_ip_via_post
    uname = fake_name
    login('yegor256')
    post('/gift', "human=#{uname}&zents=9999&summary=no")
    login(uname)
    get('/tokens')
    post('/tokens/add', 'name=foo')
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    get("/tokens/#{id}.json")
    token = JSON.parse(last_response.body)['text']
    get('/push')
    header('User-Agent', 'something')
    name = fake_name
    ip = '192.168.0.1'
    post('/push', { 'name' => name, 'token' => token }, 'REMOTE_ADDR' => ip)
    assert_status(302)
    human = app.humans.find(uname)
    job = human.jobs.recent(name)
    assert_equal(ip, job.ip)
  end

  def test_sends_ip_via_put
    uname = fake_name
    login('yegor256')
    post('/gift', "human=#{uname}&zents=9999&summary=no")
    login(uname)
    get('/tokens')
    post('/tokens/add', 'name=foo')
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    get("/tokens/#{id}.json")
    token = JSON.parse(last_response.body)['text']
    fb = Factbase.new
    (0..100).each do |i|
      fb.insert.foo = "booom \x01\x02\x03 #{i}"
    end
    header('X-Zerocracy-Token', token)
    header('User-Agent', 'something')
    header('Content-Type', 'application/zip')
    header(
      'X-Zerocracy-Meta',
      [
        Base64.encode64('vitals_url:https://zerocracy.com'),
        Base64.encode64('how are you, друг?')
      ].join('  ')
    )
    name = fake_name
    ip = '192.168.0.1'
    put("/push/#{name}", fb.export, 'REMOTE_ADDR' => ip)
    assert_status(200)
    human = app.humans.find(uname)
    job = human.jobs.recent(name)
    assert_equal(ip, job.ip)
  end

  def test_call_lock_via_put
    uname = fake_name
    login('yegor256')
    post('/gift', "human=#{uname}&zents=9999&summary=no")
    login(uname)
    get('/tokens')
    post('/tokens/add', 'name=foo')
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    get("/tokens/#{id}.json")
    token = JSON.parse(last_response.body)['text']
    fb = Factbase.new
    (0..100).each do |i|
      fb.insert.foo = "booom \x01\x02\x03 #{i}"
    end
    header('X-Zerocracy-Token', token)
    header('User-Agent', 'something')
    header('Content-Type', 'application/zip')
    header(
      'X-Zerocracy-Meta',
      [
        Base64.encode64('vitals_url:https://zerocracy.com'),
        Base64.encode64('how are you, друг?')
      ].join('  ')
    )
    name = fake_name
    put("/push/#{name}?owner=baza", fb.export)
    assert_status(200)
    human = app.humans.find(uname)
    assert(human.locks.locked?(name))
  end

  private

  def make_valid_token
    uname = fake_name
    login('yegor256')
    post('/gift', "human=#{uname}&zents=555555&summary=no")
    login(uname)
    get('/tokens')
    post('/tokens/add', 'name=foo')
    id = last_response.headers['X-Zerocracy-TokenId'].to_i
    get("/tokens/#{id}.json")
    JSON.parse(last_response.body)['text']
  end
end
