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
require 'factbase'
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
    loog = Loog::Buffer.new
    humans = Baza::Humans.new(fake_pgsql)
    fbs = Baza::Factbases.new('', '', loog:)
    Dir.mktmpdir do |lib|
      %w[judges/foo lib].each { |d| FileUtils.mkdir_p(File.join(lib, d)) }
      File.write(
        File.join(lib, 'judges/foo/foo.rb'),
        '
        if $fb.query("(exists foo)").each.to_a.empty?
          $valve.enter("boom", "the reason") do
            $fb.insert.foo = 42
          end
        end
        '
      )
      pipeline = Baza::Pipeline.new(lib, humans, fbs, loog)
      pipeline.start(0.1)
      human = humans.ensure(fake_name)
      admin = humans.ensure('yegor256')
      admin.secrets.add(fake_name, 'ZEROCRAT_TOKEN', 'nothing interesting')
      token = human.tokens.add(fake_name)
      uuid =
        Tempfile.open do |f|
          File.binwrite(f, Factbase.new.export)
          uuid = fbs.save(f.path)
        end
      job = token.start(fake_name, uuid, 1, 0, 'n/a', ['vitals_url:abc', 'ppp:hello'])
      assert(!human.jobs.get(job.id).finished?)
      human.secrets.add(job.name, 'ppp', 'swordfish')
      loop do
        j = human.jobs.get(job.id)
        next unless j.finished?
        assert(!j.result.empty?)
        break
      end
      pipeline.stop
      stdout = loog.to_s
      [
        'Pipeline started',
        'Running foo (#0)',
        'The following options provided',
        'PPP → "swor*****"',
        'VITALS_URL → "abc"',
        'ZEROCRAT_TOKEN → "noth***************"',
        'Update finished in 2 cycle(s), modified 1/0 fact(s)',
        'Pipeline stopped'
      ].each { |t| assert(stdout.include?(t), "Can't find '#{t}' in #{stdout}") }
      Tempfile.open do |f|
        job = human.jobs.get(job.id)
        fbs.load(job.result.uri2, f.path)
        fb = Factbase.new
        fb.import(File.binread(f))
        assert_equal(2, fb.size)
        assert_equal(42, fb.query('(exists foo)').each.to_a.first.foo)
      end
    end
  end
end
