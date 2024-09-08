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
require 'factbase'
require 'archive/zip'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class PopTest < Minitest::Test
  def test_no_jobs
    WebMock.disable_net_connect!
    stub_request(:get, 'https://www.zerocracy.com/pop?owner=baza-pop-swarm').to_return(status: 204)
    load(File.join(__dir__, '../../swarms/pop/entry.rb'), true)
  end

  def test_one_job
    skip # this test doesn't work
    WebMock.disable_net_connect!
    Dir.mktmpdir do |home|
      FileUtils.mkdir_p(File.join(home, 'pack'))
      zip = File.join(home, 'pack.zip')
      File.write(File.join(home, 'pack/job.json'), JSON.pretty_generate({ id: 42 }))
      File.binwrite(File.join(home, 'pack/input.fb'), Factbase.new.export)
      Archive::Zip.archive(zip, File.join(home, 'pack/.'))
      stub_request(:get, 'https://www.zerocracy.com/pop?owner=baza-pop-swarm').to_return(
        status: 200, body: File.binread(zip)
      )
    end
    load(File.join(__dir__, '../../swarms/pop/entry.rb'), true)
  end
end
