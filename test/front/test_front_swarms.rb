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
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../baza'

class Baza::FrontSwarmsTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_read_swarms
    human = fake_job.jobs.human
    fake_login(human.github)
    swarms = human.swarms
    n = fake_name
    repo = "#{fake_name}/#{fake_name}"
    branch = fake_name
    swarm = swarms.add(n, repo, branch, '/')
    get('/swarms')
    assert_status(200)
    get("/swarms/#{swarm.id}/disable")
    assert_status(302)
  end

  def test_swarms_webhook
    human = fake_job.jobs.human
    fake_login(human.github)
    swarms = human.swarms
    n = fake_name
    repo = "#{fake_name}/#{fake_name}"
    branch = fake_name
    swarms.add(n, repo, branch, '/')
    post(
      '/swarms/webhook',
      JSON.pretty_generate(
        {
          ref: "refs/head/#{branch}",
          after: '373737373737373737373737373737373737abcd',
          repository: { full_name: repo }
        }
      ),
      'CONTENT_TYPE' => 'application/json'
    )
    assert_status(200)
    post(
      '/swarms/webhook',
      JSON.pretty_generate(
        {
          ref: 'refs/head/another-branch',
          after: '3737373737373737373737373737373737373737',
          repository: { full_name: repo }
        }
      ),
      'CONTENT_TYPE' => 'application/json'
    )
    assert_status(200)
    post(
      '/swarms/webhook',
      JSON.pretty_generate(
        {
          ref: "refs/head/#{branch}",
          after: '3737373737373737373737373737373737373737',
          repository: { full_name: 'wrong-org/wrong-repo' }
        }
      ),
      'CONTENT_TYPE' => 'application/json'
    )
    assert_status(400)
  end

  def test_swarms_finish
    human = fake_job.jobs.human
    fake_login(human.github)
    swarms = human.swarms
    s = swarms.add(fake_name, "#{fake_name}/#{fake_name}", fake_name, '/')
    secret = fake_name
    r = s.releases.start('tail', secret)
    put(
      "/swarms/finish?head=4242424242424242424242424242424242424242&exit=0&sec=42&secret=#{secret}",
      'this is stdout',
      'CONTENT_TYPE' => 'text/plain'
    )
    assert_status(200)
    assert(s.releases.get(r.id).tail.include?('this is'))
  end

  def test_reset_release
    human = fake_job.jobs.human
    fake_login(human.github)
    swarms = human.swarms
    s = swarms.add(fake_name, "#{fake_name}/#{fake_name}", fake_name, '/')
    secret = fake_name
    r = s.releases.start('tail', secret)
    get("/swarms/#{s.id}/releases/#{r.id}/reset")
    assert_status(302)
    get("/swarms/#{s.id}/reset")
    assert_status(302)
  end

  def test_get_files
    s = fake_human.swarms.add(fake_name, "#{fake_name}/#{fake_name}", fake_name, '/')
    get("/swarms/#{s.id}/files?script=release&secret=#{s.secret}")
    assert_status(200)
  end

  def test_register_invocation
    job = fake_job
    human = job.jobs.human
    swarms = human.swarms
    s = swarms.add(fake_name, "#{fake_name}/#{fake_name}", fake_name, '/')
    put(
      "/swarms/#{s.id}/invocation?job=#{job.id}&secret=#{s.secret}",
      'this is stdout',
      'CONTENT_TYPE' => 'text/plain'
    )
    assert_status(200)
    assert(s.invocations.each.to_a.first[:stdout].include?('this is'))
    fake_login(human.github)
    get("/swarms/#{s.id}/invocations")
    assert_status(200)
  end

  def test_register_non_job_invocation
    swarms = fake_human.swarms
    s = swarms.add(fake_name, "#{fake_name}/#{fake_name}", fake_name, '/')
    put(
      "/swarms/#{s.id}/invocation?secret=#{s.secret}",
      'this is a non-job stdout',
      'CONTENT_TYPE' => 'text/plain'
    )
    assert_status(200)
    assert(s.invocations.each.to_a.first[:stdout].include?('this is'))
    fake_login(swarms.human.github)
    get("/swarms/#{s.id}/invocations")
    assert_status(200)
  end

  def test_pop_one
    fake_job
    fbs = Baza::Factbases.new('', '', loog: fake_loog)
    pipe = Baza::Humans.new(fake_pgsql).pipe(fbs)
    assert(!pipe.pop('owner').nil?)
  end

  def test_pack
    fbs = Baza::Factbases.new('', '', loog: fake_loog)
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'foo.fb')
      File.binwrite(input, Factbase.new.export)
      uri = fbs.save(input)
      job = fake_token.start(fake_name, uri, 1, 0, 'n/a', [], '1.1.1.1')
      alt = job.jobs.human.alterations.add(job.name, 'ruby', { script: '42 + 1"' })
      pipe = Baza::Humans.new(fake_pgsql).pipe(fbs)
      zip = File.join(dir, 'foo.zip')
      pipe.pack(job, zip)
      Baza::Zip.new(zip).unpack(dir)
      ['job.json', 'base.fb', "alteration-#{alt}/alteration-#{alt}.rb"].each do |f|
        assert(File.exist?(File.join(dir, f)), f)
      end
      json = JSON.parse(File.read(File.join(dir, 'job.json')))
      assert_equal(job.id, json['id'], json)
      assert_equal(job.name, json['name'], json)
    end
  end

  def test_unpack
    job = fake_job
    fbs = Baza::Factbases.new('', '', loog: fake_loog)
    pipe = Baza::Humans.new(fake_pgsql).pipe(fbs)
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, 'base.fb'), Factbase.new.export)
      File.write(File.join(dir, 'stdout.txt'), 'Nothing interesting')
      File.write(
        File.join(dir, 'job.json'),
        JSON.pretty_generate(
          {
            id: job.id,
            exit: 0,
            msec: 500
          }
        )
      )
      zip = File.join(dir, 'foo.zip')
      Baza::Zip.new(zip).pack(dir)
      pipe.unpack(job, zip)
      assert(job.jobs.get(job.id).finished?)
    end
  end
end
