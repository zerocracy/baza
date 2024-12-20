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
require 'threads'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/factbases'
require_relative '../../objects/baza/pipe'
require_relative '../../objects/baza/zip'

# Test for Pipe.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::PipeTest < Minitest::Test
  def test_simple_pop
    fake_pgsql.exec('TRUNCATE job CASCADE')
    fake_job
    owner = fake_name
    assert(!fake_pipe.pop(owner).nil?)
    assert(!fake_pipe.pop(owner).nil?)
    assert(!fake_pipe.pop(owner).nil?)
    assert(fake_pipe.pop('another owner').nil?)
  end

  def test_pop_in_threads
    fake_pgsql.exec('TRUNCATE job CASCADE')
    total = 5
    total.times { fake_job }
    pipe = fake_pipe
    popped = Concurrent::Array.new
    Threads.new(total * 10).assert do
      job = pipe.pop(fake_name)
      popped.push(job.id) unless job.nil?
    end
    assert_equal(total, popped.size)
  end

  def test_pop_the_same_if_not_processed
    fake_pgsql.exec('TRUNCATE job CASCADE')
    fake_job
    owner = fake_name
    job = fake_pipe.pop(owner)
    assert_equal(job.id, fake_pipe.pop(owner).id)
    job.untake!
    assert(!fake_pipe.pop('another owner').nil?)
  end

  def test_simple_pack
    fake_job
    job = fake_pipe.pop('owner')
    Dir.mktmpdir do |home|
      zip = File.join(home, 'foo.zip')
      fake_pipe.pack(job, zip)
      Baza::Zip.new(zip, loog: fake_loog).unpack(File.join(home, 'pack'))
      assert(File.exist?(File.join(home, 'pack/base.fb')))
    end
  end

  def test_simple_unpack
    fake_job
    job = fake_pipe.pop('owner')
    Dir.mktmpdir do |home|
      zip = File.join(home, 'foo.zip')
      fake_pipe.pack(job, zip)
      Baza::Zip.new(zip).unpack(File.join(home, 'pack'))
      File.delete(zip)
      FileUtils.mkdir_p(File.join(home, 'pack/42'))
      File.write(File.join(home, 'pack/42/stdout.txt'), 'nothing...')
      File.write(File.join(home, 'pack/42/exit.txt'), '0')
      File.write(File.join(home, 'pack/42/msec.txt'), '500')
      Baza::Zip.new(zip, loog: fake_loog).pack(File.join(home, 'pack/.'))
      fake_pipe.unpack(job, zip)
    end
  end

  def test_pack_with_alterations
    fbs = Baza::Factbases.new('', '', loog: fake_loog)
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'foo.fb')
      File.binwrite(input, Factbase.new.export)
      uri = fbs.save(input)
      job = fake_token.start(fake_name, uri, 1, 0, 'n/a', [], '1.1.1.1')
      alt = job.jobs.human.alterations.add(job.name, 'ruby', { script: '42 + 1"' })
      pipe = Baza::Humans.new(fake_pgsql).pipe(fbs, nil)
      zip = File.join(dir, 'foo.zip')
      pipe.pack(job, zip)
      Baza::Zip.new(zip).unpack(dir)
      ['job.json', 'base.fb', "alteration-#{alt}.rb"].each do |f|
        assert(File.exist?(File.join(dir, f)), f)
      end
      json = JSON.parse(File.read(File.join(dir, 'job.json')))
      assert_equal(job.id, json['id'], json)
      assert_equal(job.name, json['name'], json)
    end
  end

  def test_unpack_with_alterations
    fbs = Baza::Factbases.new('', '', loog: fake_loog)
    Dir.mktmpdir do |home|
      input = File.join(home, 'foo.fb')
      File.binwrite(input, Factbase.new.export)
      uri = fbs.save(input)
      job = fake_token.start(fake_name, uri, 1, 0, 'n/a', [], '1.1.1.1')
      alt = job.jobs.human.alterations.add(job.name, 'ruby', { script: '42 + 1"' })
      pipe = Baza::Humans.new(fake_pgsql).pipe(fbs, nil)
      zip = File.join(home, 'foo.zip')
      pipe.pack(job, zip)
      Baza::Zip.new(zip).unpack(home)
      File.delete(zip)
      File.write(File.join(home, "alteration-#{alt}.txt"), 'done...')
      Baza::Zip.new(zip, loog: fake_loog).pack(home)
      fake_pipe.unpack(job, zip)
      assert(!job.jobs.human.alterations.get(alt)[:applied].nil?)
    end
  end

  def test_unpack_with_trails
    fake_job
    job = fake_pipe.pop('owner')
    Dir.mktmpdir do |home|
      zip = File.join(home, 'foo.zip')
      fake_pipe.pack(job, zip)
      Baza::Zip.new(zip).unpack(File.join(home, 'pack'))
      File.delete(zip)
      FileUtils.mkdir_p(File.join(home, 'pack/42/trails/foo'))
      File.write(File.join(home, 'pack/42/stdout.txt'), 'nothing...')
      File.write(File.join(home, 'pack/42/trails/foo/bar.json'), '{ "something": 42}')
      Baza::Zip.new(zip, loog: fake_loog).pack(File.join(home, 'pack/.'))
      fake_pipe.unpack(job, zip)
      trails = Baza::Trails.new(fake_pgsql)
      trails.each.to_a.any? do |t|
        t[:job] == job.id && t[:judge] == 'foo' && t[:name] == 'bar.json' && t[:json]['something'] == 42
      end
    end
  end

  def test_unpack_from_scratch
    job = fake_job
    pipe = fake_pipe
    Dir.mktmpdir do |dir|
      File.binwrite(File.join(dir, 'base.fb'), Factbase.new.export)
      zip = File.join(dir, 'foo.zip')
      Baza::Zip.new(zip).pack(dir)
      pipe.unpack(job, zip)
      assert(job.jobs.get(job.id).finished?)
    end
  end

  private

  def fake_pipe
    humans = fake_humans
    fbs = Baza::Factbases.new('', '', loog: fake_loog)
    Baza::Pipe.new(humans, fbs, Baza::Trails.new(fake_pgsql), loog: fake_loog)
  end
end
