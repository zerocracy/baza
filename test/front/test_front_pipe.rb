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
require_relative '../../objects/baza/zip'

class Baza::FrontPipeTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_pop_and_finish_job
    finish_all_jobs
    fake_login('yegor256')
    fake_job
    get('/pop?owner=foo')
    assert_equal(200, last_response.status, last_response.body)
    Dir.mktmpdir do |dir|
      zip = File.join(dir, 'foo.zip')
      File.binwrite(zip, last_response.body)
      Baza::Zip.new(zip).unpack(dir)
      json = File.join(dir, 'job.json')
      meta = JSON.parse(File.read(json))
      id = meta['id']
      File.binwrite(File.join(dir, 'output.fb'), Factbase.new.export)
      meta[:exit] = 0
      meta[:msec] = 500
      File.write(json, JSON.pretty_generate(meta))
      File.write(File.join(dir, 'stdout.txt'), 'all good!')
      Baza::Zip.new(zip).pack(dir)
      put("/finish?id=#{id}", File.binread(zip), 'CONTENT_TYPE' => 'application/octet-stream')
      assert_equal(200, last_response.status, last_response.body)
    end
  end
end
