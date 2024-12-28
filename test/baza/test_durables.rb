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

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::DurablesTest < Baza::Test
  def test_simple_scenario
    fbs = Baza::Factbases.new('', '')
    job = fake_job
    durables = job.jobs.human.durables(fbs)
    owner = 'it is me'
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'test.bin')
      data = 'test me'
      File.binwrite(file, data)
      durable = durables.place(job.name, File.basename(file), file)
      assert_equal(durable.id, durables.place(job.name, File.basename(file), file).id)
      durable.lock(owner)
      durable.lock(owner)
      assert_raises(Baza::Durable::Busy) { durable.lock('another owner') }
      durable.lock(owner)
      FileUtils.rm_f(file)
      durable.load(file)
      assert(File.exist?(file))
      assert_equal(data, File.binread(file))
      durable.save(file)
      durable.save(file)
      durable.unlock(owner)
      durable.delete
    end
  end

  def test_place_shareable
    fbs = Baza::Factbases.new('', '')
    humans = Baza::Humans.new(fake_pgsql)
    admin = humans.ensure('yegor256')
    human = humans.ensure(fake_name)
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'test.bin')
      data = 'test me'
      File.binwrite(file, data)
      n = "@#{fake_name}"
      id = admin.durables(fbs).place('test', n, file).id
      durable = human.durables(fbs).place('x', n, file)
      assert_equal(id, durable.id)
      assert(!durable.uri.nil?)
      durable.lock('test')
      durable.load(file)
      durable.save(file)
      durable.unlock('test')
    end
  end

  def test_update_two_by_admin
    fbs = Baza::Factbases.new('', '')
    humans = Baza::Humans.new(fake_pgsql)
    admin = humans.ensure('yegor256')
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'test.bin')
      data = 'test me'
      File.binwrite(file, data)
      n1 = "@#{fake_name}"
      n2 = "@#{fake_name}"
      admin.durables(fbs).place('test', n1, file).id
      admin.durables(fbs).place('test', n2, file).id
      durable = admin.durables(fbs).place('x', n2, file)
      durable.lock('test')
      durable.save(file)
    end
  end
end
