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
require_relative '../../baza'

class Baza::FrontDurablesTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_full_cycle
    fake_login
    body = 'hello, world!'
    place(fake_name, fake_name, body)
    assert_status(302)
    id = last_response.headers['X-Zerocracy-DurableId'].to_i
    get("/durables/#{id}")
    assert_status(200)
    assert_equal(body, last_response.body)
    get("/durables/#{id}/lock?owner=foobar")
    assert_status(302)
    put("/durables/#{id}", 'second body')
    assert_status(200)
    get("/durables/#{id}")
    assert_equal('second body', last_response.body)
    get("/durables/#{id}/unlock?owner=foobar")
    assert_status(302)
    get('/durables')
    assert_status(200)
    get("/durables/#{id}/remove")
    assert_status(302)
  end

  def test_place_twice
    fake_login
    jname = fake_name
    file = fake_name
    place(jname, file, 'first')
    assert_status(302)
    first = last_response.headers['X-Zerocracy-DurableId'].to_i
    place(jname, file, 'second')
    assert_status(302)
    second = last_response.headers['X-Zerocracy-DurableId'].to_i
    assert_equal(first, second)
  end

  private

  def place(jname, file, body)
    Tempfile.open do |f|
      File.binwrite(f.path, body)
      post(
        '/durables/place',
        'jname' => jname,
        'file' => file,
        'zip' => Rack::Test::UploadedFile.new(f.path, 'application/zip')
      )
    end
  end
end
