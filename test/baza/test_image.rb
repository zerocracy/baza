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
require 'fileutils'
require 'loog'
require 'typhoeus'
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/zip'
require_relative '../../objects/baza/image'

# Test for Image.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::ImageTest < Minitest::Test
  def test_fake_docker_run
    WebMock.enable_net_connect!
    loog = Loog::VERBOSE
    Dir.mktmpdir do |home|
      zip = File.join(home, 'image.zip')
      Baza::Image.new(fake_humans, '42424242', 'us-east-1', loog:,
        from: 'public.ecr.aws/lambda/ruby:3.2').pack(zip)
      Baza::Zip.new(zip).unpack(home)
      bash("docker build #{home} -t image-test", loog)
      stdout = bash("docker run -d -p 9000:8080 image-test", loog)
      container = stdout.split("\n")[-1]
      loog.debug("Docker container started: #{container}")
      begin
        sleep 1
        request = Typhoeus::Request.new(
          "http://localhost:9000/2015-03-31/functions/function/invocations",
          body: '{}',
          method: :get
        )
        request.run
        ret = request.response
        bash("docker logs #{container}", loog)
      ensure
        bash("docker rm -f #{container}", loog)
      end
      assert_equal(200, ret.response_code, ret.response_body)
      assert_equal('"Done!"', ret.response_body, ret.response_body)
    end
  end

  private

  def bash(cmd, loog)
    stdout = `#{cmd} 2>&1`
    loog.debug(stdout)
    assert_equal(0, $CHILD_STATUS.exitstatus)
    stdout
  end
end
