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
require 'base64'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/humans'
require_relative '../../objects/baza/verified'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::VerifiedTest < Minitest::Test
  def test_simple_check
    WebMock.disable_net_connect!
    human = Baza::Humans.new(fake_pgsql).ensure(fake_name)
    token = human.tokens.add(fake_name)
    ip = '192.168.1.1'
    url = 'https://github.com/foo/foo/actions/runs/555'
    id = token.start(fake_name, fake_name, 1, 0, 'n/a', ["workflow_url:#{url}"], ip).id
    job = human.jobs.get(id)
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/runs/555').to_return(
      body: { path: '.github/workflows/a.yml@master' }.to_json, headers: {
        'content-type': 'application/json'
      }
    )
    stub_request(:get, 'https://api.github.com/repos/foo/foo/contents/.github/workflows/a.yml?ref=master').to_return(
      body: {
        content: Base64.encode64("jobs:\n  zerocracy:\n    steps:\n      - uses: zerocracy/judges-action@0.0.39\n")
      }.to_json,
      headers: { 'content-type': 'application/json' }
    )
    v = Baza::Verified.new(job).verdict
    assert(v.start_with?('OK: All good'))
  end

  def test_missing_workflow_page
    WebMock.disable_net_connect!
    human = Baza::Humans.new(fake_pgsql).ensure(fake_name)
    token = human.tokens.add(fake_name)
    ip = '192.168.1.1'
    id = token.start(
      fake_name, fake_name, 1, 0, 'n/a',
      ['workflow_url:https://github.com/foo/foo/actions/runs/22'],
      ip
    ).id
    job = human.jobs.get(id)
    stub_request(:get, 'https://api.github.com/repos/foo/foo/actions/runs/22').to_return(status: 404)
    v = Baza::Verified.new(job).verdict
    assert(v.include?('FAKE: Workflow URL https://github.com/foo/foo/actions/runs/22 not found'))
  end

  def test_missed_meta
    human = Baza::Humans.new(fake_pgsql).ensure(fake_name)
    token = human.tokens.add(fake_name)
    ip = '192.168.1.1'
    id = token.start(fake_name, fake_name, 1, 0, 'n/a', [], ip).id
    job = human.jobs.get(id)
    v = Baza::Verified.new(job).verdict
    assert_equal('FAKE: There is no workflow_url meta', v)
  end

  def test_broken_meta
    human = Baza::Humans.new(fake_pgsql).ensure(fake_name)
    token = human.tokens.add(fake_name)
    ip = '192.168.1.1'
    id = token.start(fake_name, fake_name, 1, 0, 'n/a', ['workflow_url:hey'], ip).id
    job = human.jobs.get(id)
    v = Baza::Verified.new(job).verdict
    assert_equal('FAKE: Wrong URL at workflow_url: "hey"', v)
  end
end
