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
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/pipe'

# Test for Pipe.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::PipeTest < Minitest::Test
  def test_pop_one
    fake_job
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
    pipe = Baza::Humans.new(fake_pgsql).pipe(fbs)
    assert(!pipe.pop('owner').nil?)
  end

  def test_pack
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'foo.fb')
      File.binwrite(input, Factbase.new.export)
      uri = fbs.save(input)
      job = fake_token.start(fake_name, uri, 1, 0, 'n/a', [], '1.1.1.1')
      alt = job.jobs.human.alterations.add(job.name, 'ruby', { script: 'puts "hi!"' })
      pipe = Baza::Humans.new(fake_pgsql).pipe(fbs)
      zip = File.join(dir, 'foo.zip')
      pipe.pack(job, zip)
      Zip::File.open(zip) do |z|
        z.each do |entry|
          entry.extract(File.join(dir, entry.name))
        end
      end
      assert(File.exist?(File.join(dir, "#{job.id}.json")))
      assert(File.exist?(File.join(dir, "#{job.id}.fb")))
      assert(File.exist?(File.join(dir, "alteration-#{alt}.rb")))
      json = JSON.parse(File.read(File.join(dir, "#{job.id}.json")))
      assert_equal(job.id, json['id'], json)
      assert_equal(job.name, json['name'], json)
    end
  end

  def test_unpack
    job = fake_job
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
    pipe = Baza::Humans.new(fake_pgsql).pipe(fbs)
    Dir.mktmpdir do |dir|
      output = File.join(dir, "#{job.id}.fb")
      File.binwrite(output, Factbase.new.export)
      stdout = File.join(dir, "#{job.id}.stdout")
      File.write(stdout, 'Nothing interesting')
      json = File.join(dir, "#{job.id}.json")
      File.write(
        json,
        JSON.pretty_generate(
          {
            id: job.id,
            exit: 0,
            msec: 500
          }
        )
      )
      zip = File.join(dir, 'foo.zip')
      Zip::File.open(zip, create: true) do |z|
        z.add(File.basename(output), output)
        z.add(File.basename(stdout), stdout)
        z.add(File.basename(json), json)
      end
      pipe.unpack(job, zip)
      assert(job.jobs.get(job.id).finished?)
    end
  end
end
