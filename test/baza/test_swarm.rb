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

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::SwarmTest < Baza::Test
  def test_simple_scenario
    human = fake_human
    swarms = human.swarms
    n = fake_name.downcase
    s = swarms.add(n, "zerocracy/#{fake_name}", 'master', '/')
    assert_equal(n, s.name)
    assert(s.repository.start_with?('zerocracy/'))
    assert_equal('master', s.branch)
  end

  def test_no_release_when_another_running
    human = fake_human
    s = human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
    s.head!(fake_sha)
    assert_nil(s.why_not)
    s.releases.start('no tail', fake_name)
    assert(s.why_not.include?('not yet finished'), s.why_not)
  end

  def test_no_release_when_too_soon
    human = fake_human
    s = human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
    sha = fake_sha
    s.head!(fake_sha)
    r = s.releases.start('no tail', fake_name)
    r.finish!(fake_sha, Baza::VERSION, 'tail', 0, 42)
    assert(s.why_not.include?('only then will release again'), s.why_not)
  end

  def test_no_release_when_heads_are_similar
    human = fake_human
    s = human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
    sha = fake_sha
    s.head!(sha)
    r = s.releases.start('no tail', fake_name, created: Time.now - 100 * 60 * 60)
    r.finish!(sha, Baza::VERSION, 'tail', 0, 42)
    assert(s.why_not.include?('equals to the SHA of the head'), s.why_not)
  end

  def test_release_when_heads_are_similar_but_versions_different
    human = fake_human
    s = human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
    sha = fake_sha
    s.head!(sha)
    r = s.releases.start('no tail', fake_name, created: Time.now - 100 * 60 * 60)
    r.finish!(sha, '0.0.0', 'tail', 0, 42)
    assert(s.why_not.nil?, s.why_not)
  end

  def test_no_release_when_previous_recently_failed
    human = fake_human
    s = human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
    s.head!(fake_sha)
    r = s.releases.start('no tail', fake_name)
    r.finish!(fake_sha, Baza::VERSION, 'failed!', 1, 42)
    assert(s.why_not.include?('and then make another release attempt'), s.why_not)
  end

  def test_no_release_when_no_head
    human = fake_human
    s = human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
    assert(s.why_not.include?('has just been created'), s.why_not)
  end

  def test_no_release_when_disabled_swarm
    human = fake_human('yegor256')
    s = human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
    s.enable!(false)
    assert(s.why_not.include?('is disabled'), s.why_not)
  end

  def test_no_release_when_special_same_version
    human = fake_human('yegor256')
    s = human.swarms.each.to_a.find { |e| e.name == 'pop' }
    s = human.swarms.add('pop', "zerocracy/#{fake_name}", 'master', '/') if s.nil?
    s.head!(fake_sha)
    r = s.releases.start('no tail', fake_name, created: Time.now - 100 * 60 * 60)
    r.finish!(fake_sha, Baza::VERSION, 'tail', 0, 42)
    assert(s.why_not.include?('the same as the version of Baza'), s.why_not)
  end

  def test_release_when_special_different_versions
    human = fake_human('yegor256')
    s = human.swarms.each.to_a.find { |e| e.name == 'pop' }
    s = human.swarms.add('pop', "zerocracy/#{fake_name}", 'master', '/') if s.nil?
    s.head!(fake_sha)
    r = s.releases.start('no tail', fake_name, created: Time.now - 100 * 60 * 60)
    r.finish!(fake_sha, '0.0.0', 'tail', 0, 42)
    assert(s.why_not.nil?, s.why_not)
  end

  def test_pick_latest
    human = fake_human
    s = human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
    s.head!(fake_sha)
    assert_nil(s.why_not)
    r = s.releases.start('no tail', fake_name)
    r.finish!(fake_sha, '0.999', 'tail', 0, 42)
    s.releases.start('no tail', fake_name)
    assert(!s.why_not.nil?)
  end

  def test_enable_disable
    human = fake_human
    s = human.swarms.add(fake_name.downcase, "zerocracy/#{fake_name}", 'master', '/')
    s.enable!(true)
    assert(s.enabled?)
    s.enable!(false)
    assert(!s.enabled?)
  end
end
