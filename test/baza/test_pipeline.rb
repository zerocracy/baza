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
require 'loog'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/pipeline'
require_relative '../../objects/baza/factbases'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::PipelineTest < Minitest::Test
  def test_simple_processing
    humans = Baza::Humans.new(test_pgsql)
    fbs = Baza::Factbases.new('', '')
    pipeline = Baza::Pipeline.new(humans, fbs, Loog::VERBOSE)
    pipeline.start(0.1)
    human = humans.ensure(test_name)
    token = human.tokens.add(test_name)
    uuid = Tempfile.open do |f|
      File.write(f, 'hello')
      uuid = fbs.save(f.path)
    end
    job = token.start(test_name, uuid)
    assert(!human.jobs.get(job.id).finished?)
    loop do
      j = human.jobs.get(job.id)
      next unless j.finished?
      assert(!j.result.empty?)
      break
    end
    pipeline.stop
  end
end
