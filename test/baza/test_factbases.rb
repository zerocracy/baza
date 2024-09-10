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
require 'webmock/minitest'
require 'loog'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/factbases'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::FactbasesTest < Minitest::Test
  def test_fake_usage
    fbs = Baza::Factbases.new('', '')
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'a.fb')
      File.write(input, 'hey')
      uuid = fbs.save(input)
      output = File.join(dir, 'b.fb')
      fbs.load(uuid, output)
      assert_equal('hey', File.read(output))
      fbs.delete(uuid)
    end
  end

  def test_save_to_aws
    WebMock.disable_net_connect!
    stub_request(:put, %r{https://s3.amazonaws.com/baza.zerocracy.com/.*$})
      .to_return(status: 200)
    fbs = Baza::Factbases.new('fake-key', 'fake-secret', loog: fake_loog)
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'a.fb')
      File.write(input, 'hey')
      uuid = fbs.save(input)
      assert_equal(47, uuid.length)
    end
  end

  def test_load_from_aws
    WebMock.disable_net_connect!
    stub_request(:get, %r{https://s3.amazonaws.com/baza.zerocracy.com/.*$})
      .to_return(status: 200, body: 'hello, world!')
    fbs = Baza::Factbases.new('fake-key', 'fake-secret', loog: fake_loog)
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'a.fb')
      uuid = '2024-08-13-d7956cd6-9f2c-42db-a4e3-d9186f080bfa'
      fbs.load(uuid, input)
      assert_equal(13, File.size(input))
    end
  end

  def test_load_from_aws_not_found
    WebMock.disable_net_connect!
    stub_request(:get, %r{https://s3.amazonaws.com/baza.zerocracy.com/.*$})
      .to_return(status: 404)
    fbs = Baza::Factbases.new('fake-key', 'fake-secret', loog: fake_loog)
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'a.fb')
      uuid = '2024-08-13-d7956cd6-9f2c-42db-a4e3-d9186f080bfa'
      assert(assert_raises { fbs.load(uuid, input) }.message.include?("Can't read S3 object"))
    end
  end

  def test_delete_in_aws
    WebMock.disable_net_connect!
    stub_request(:delete, %r{https://s3.amazonaws.com/baza.zerocracy.com/.*$})
      .to_return(status: 200)
    fbs = Baza::Factbases.new('fake-key', 'fake-secret', loog: fake_loog)
    uuid = '2024-08-13-d7956cd6-9f2c-42db-a4e3-d9186f080bfa'
    fbs.delete(uuid)
  end

  def test_delete_in_aws_not_found
    WebMock.disable_net_connect!
    stub_request(:delete, %r{https://s3.amazonaws.com/baza.zerocracy.com/.*$})
      .to_return(status: 404)
    fbs = Baza::Factbases.new('fake-key', 'fake-secret', loog: fake_loog)
    uuid = '2024-08-13-d7956cd6-9f2c-42db-a4e3-d9186f080bfa'
    assert(assert_raises { fbs.delete(uuid) }.message.include?("Can't delete S3 object"))
  end

  def test_live_aws_usage
    skip
    WebMock.enable_net_connect!
    fbs = Baza::Factbases.new('AKIAQJE...', 'KmX8eM...', loog: fake_loog)
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'a.fb')
      File.write(input, 'hey')
      uuid = fbs.save(input)
      output = File.join(dir, 'b.fb')
      fbs.load(uuid, output)
      assert_equal('hey', File.read(output))
    end
  end
end
