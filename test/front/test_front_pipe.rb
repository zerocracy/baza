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
require 'fileutils'
require_relative '../test__helper'
require_relative '../../baza'

class Baza::FrontPipeTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_pop_and_finish_job
    finish_all_jobs
    login('yegor256')
    fake_job
    get('/pop?owner=foo')
    assert_equal(200, last_response.status, last_response.body)
    Dir.mktmpdir do |dir|
      zip = File.join(dir, 'foo.zip')
      File.binwrite(zip, last_response.body)
      Zip::File.open(zip) do |z|
        z.each do |entry|
          entry.extract(File.join(dir, entry.name))
        end
      end
      id = File.read(File.join(dir, 'id.txt')).to_i
      fb = File.join(dir, "#{id}.fb")
      File.binwrite(fb, Factbase.new.export)
      json = File.join(dir, "#{id}.json")
      File.write(json, JSON.pretty_generate({ exit: 0, msec: 500 }))
      stdout = File.join(dir, "#{id}.stdout")
      File.write(stdout, 'all good!')
      FileUtils.rm_f(zip)
      Zip::File.open(zip, create: true) do |z|
        z.add(File.basename(fb), fb)
        z.add(File.basename(json), json)
        z.add(File.basename(stdout), stdout)
      end
      put("/finish?id=#{id}", File.binread(zip))
      assert_equal(200, last_response.status, last_response.body)
    end
  end
end
