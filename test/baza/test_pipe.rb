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
require_relative '../../objects/baza/pipe'

# Test for Pipe.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::PipeTest < Minitest::Test
  def test_pop_one
    fake_job
    pipe = Baza::Humans.new(fake_pgsql).pipe
    assert(!pipe.pop('owner').nil?)
  end

  def test_pack
    job = fake_job
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
    pipe = Baza::Humans.new(fake_pgsql).pipe(fbs)
    Dir.mktmpdir do |dir|
      zip = File.join(dir, 'foo.zip')
      pipe.pack(job, zip)
      Zip::File.open(zip) do |z|
        z.each do |entry|
          entry.extract(File.join(dir, entry.name))
        end
      end
      assert(File.exist?(File.join(dir, "#{job.id}.fb")))
    end
  end
end
