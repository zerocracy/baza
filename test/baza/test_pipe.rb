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
require_relative '../../objects/baza/factbases'
require_relative '../../objects/baza/pipe'
require_relative '../../objects/baza/zip'

# Test for Pipe.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::PipeTest < Minitest::Test
  def test_simple_pop
    fake_job
    assert(!fake_pipe.pop('owner').nil?)
  end

  def test_pop_the_same_if_not_processed
    fake_pgsql.exec('TRUNCATE job CASCADE')
    fake_job
    owner = fake_name
    job = fake_pipe.pop(owner)
    assert_equal(job.id, fake_pipe.pop(owner).id)
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
      File.write(File.join(home, 'pack/stdout.txt'), 'nothing...')
      File.write(
        File.join(home, 'pack/job.json'),
        JSON.pretty_generate(
          JSON.parse(File.read(File.join(home, 'pack/job.json'))).merge(
            { 'exit' => 0, 'msec' => 500 }
          )
        )
      )
      Baza::Zip.new(zip, loog: fake_loog).pack(File.join(home, 'pack/.'))
      fake_pipe.unpack(job, zip)
    end
  end

  private

  def fake_pipe
    humans = fake_humans
    fbs = Baza::Factbases.new('', '', loog: fake_loog)
    Baza::Pipe.new(humans, fbs, loog: fake_loog)
  end
end
