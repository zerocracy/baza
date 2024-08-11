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
require 'factbase'
require 'wait_for'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/pipeline'
require_relative '../../objects/baza/factbases'
require_relative '../../objects/baza/trails'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::PipelineTest < Minitest::Test
  def setup
    loop do
      Dir.mktmpdir do |home|
        process_all(home, Baza::Humans.new(fake_pgsql), Baza::Factbases.new('', ''))
      end
      break
    rescue StandardError
      retry
    end
  end

  def test_simple_processing
    loog = Loog::Buffer.new
    humans = Baza::Humans.new(fake_pgsql)
    fbs = Baza::Factbases.new('', '', loog:)
    Dir.mktmpdir do |home|
      %w[judges/foo lib].each { |d| FileUtils.mkdir_p(File.join(home, d)) }
      File.write(
        File.join(home, 'judges/foo/foo.rb'),
        '
        if $fb.query("(exists foo)").each.to_a.empty?
          $valve.enter("boom", "the reason") do
            $fb.insert.foo = 42
          end
        end
        '
      )
      human = humans.ensure(fake_name)
      admin = humans.ensure('yegor256')
      admin.secrets.add(fake_name, 'ZEROCRAT_TOKEN', 'nothing interesting')
      token = human.tokens.add(fake_name)
      job = token.start(fake_name, uri(fbs), 1, 0, 'n/a', ['vitals_url:abc', 'ppp:hello'], '192.168.1.1')
      assert(!human.jobs.get(job.id).finished?)
      human.secrets.add(job.name, 'ppp', 'swordfish')
      process_all(home, humans, fbs, loog:)
      assert(human.jobs.get(job.id).finished?)
      stdout = loog.to_s
      [
        'Running foo (#0)',
        'The following options provided',
        'PPP → "swor*fish"',
        'VITALS_URL → "abc"',
        'ZEROCRAT_TOKEN → "noth***********ting"',
        'Update finished in 2 cycle(s), modified 1/0 fact(s)'
      ].each { |t| assert(stdout.include?(t), "Can't find '#{t}' in #{stdout}") }
      Tempfile.open do |f|
        job = human.jobs.get(job.id)
        assert(!job.result.empty?)
        fbs.load(job.result.uri2, f.path)
        fb = Factbase.new
        fb.import(File.binread(f))
        assert_equal(2, fb.size)
        assert_equal(42, fb.query('(exists foo)').each.to_a.first.foo)
      end
      assert(!human.locks.locked?(job.name))
    end
  end

  def test_picks_all_of_them
    humans = Baza::Humans.new(fake_pgsql)
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
    Dir.mktmpdir do |home|
      human = humans.ensure(fake_name)
      token = human.tokens.add(fake_name)
      first = token.start(fake_name, uri(fbs), 1, 0, 'n/a', [], '192.168.1.1')
      second = token.start(fake_name, uri(fbs), 1, 0, 'n/a', [], '192.168.1.1')
      process_all(home, humans, fbs)
      assert(human.jobs.get(first.id).finished?, first.id)
      assert(human.jobs.get(second.id).finished?, second.id)
    end
  end

  def test_with_fatal_error
    humans = Baza::Humans.new(fake_pgsql)
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
    Dir.mktmpdir do |home|
      human = humans.ensure(fake_name)
      token = human.tokens.add(fake_name)
      job = token.start(fake_name, fake_name, 1, 0, 'n/a', [], '192.168.1.1')
      assert_raises { process_all(home, humans, fbs) }
      assert(human.jobs.get(job.id).finished?)
      job = human.jobs.get(job.id)
      assert(!job.result.nil?)
      assert(!job.result.exit.zero?)
      assert(job.result.stdout.include?('No such file or directory'), job.result.stdout)
      assert(!human.locks.locked?(job.name))
    end
  end

  def test_with_two_alterations
    humans = Baza::Humans.new(fake_pgsql)
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
    Dir.mktmpdir do |home|
      FileUtils.mkdir_p(File.join(home, 'lib'))
      FileUtils.mkdir_p(File.join(home, 'judges/foo'))
      File.write(File.join(home, 'judges/foo/foo.rb'), 'x = 42')
      human = humans.ensure(fake_name)
      n = fake_name
      human.alterations.add(n, 'ruby', script: '$fb.insert.foo = 42')
      human.alterations.add(n, 'ruby', script: '$fb.insert.bar = 7')
      token = human.tokens.add(fake_name)
      job = token.start(n, uri(fbs), 1, 0, 'n/a', [], '192.168.1.1')
      process_all(home, humans, fbs)
      assert(human.jobs.get(job.id).finished?)
      Tempfile.open do |f|
        job = human.jobs.get(job.id)
        assert_equal(0, job.result.exit, job.result.stdout)
        fbs.load(job.result.uri2, f.path)
        fb = Factbase.new
        fb.import(File.binread(f))
        assert_equal(2, fb.size)
        { foo: 42, bar: 7 }.each do |k, v|
          assert_equal(v, fb.query("(exists #{k})").each.to_a.first[k.to_s].first)
        end
      end
    end
  end

  def test_with_trails
    humans = Baza::Humans.new(fake_pgsql)
    trails = Baza::Trails.new(fake_pgsql)
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
    Dir.mktmpdir do |home|
      FileUtils.mkdir_p(File.join(home, 'lib'))
      FileUtils.mkdir_p(File.join(home, 'judges/foo'))
      File.write(
        File.join(home, 'judges/foo/foo.rb'),
        '
        require "fileutils"
        require "json"
        p $options.trails_dir
        FileUtils.mkdir(File.join($options.trails_dir, "bar"))
        File.write(File.join($options.trails_dir, "bar/bar.json"), {"hello":42}.to_json)
        '
      )
      human = humans.ensure(fake_name)
      token = human.tokens.add(fake_name)
      job = token.start(fake_name, uri(fbs), 1, 0, 'n/a', [], '192.168.1.1')
      process_all(home, humans, fbs)
      assert(job.jobs.get(job.id).finished?)
      job = job.jobs.get(job.id)
      assert_equal(0, job.result.exit, job.result.stdout)
    end
    assert(!trails.each.to_a.find { |t| t[:name] == 'bar.json' }.nil?)
  end

  private

  def process_all(home, humans, fbs, loog: Loog::NULL)
    FileUtils.mkdir_p(File.join(home, 'judges'))
    pp = Baza::Pipeline.new(home, humans, fbs, loog, Baza::Trails.new(fake_pgsql))
    loop do
      break unless pp.process_one
    end
  end

  def uri(fbs)
    Tempfile.open do |f|
      File.binwrite(f, Factbase.new.export)
      fbs.save(f.path)
    end
  end
end
