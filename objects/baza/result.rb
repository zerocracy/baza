# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2025 Zerocracy
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

# One job.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Result
  attr_reader :id, :results

  def initialize(results, id)
    @results = results
    raise 'Result ID must be an integer' unless id.is_a?(Integer)
    @id = id
  end

  def created
    Time.parse(@results.pgsql.exec('SELECT created FROM result WHERE id = $1', [@id])[0]['created'])
  end

  def empty?
    uri2.nil?
  end

  def uri2
    @results.pgsql.exec('SELECT uri2 FROM result WHERE id = $1', [@id])[0]['uri2']
  end

  def size
    s = @results.pgsql.exec('SELECT size FROM result WHERE id = $1', [@id])[0]['size']
    s.nil? ? s : s.to_i
  end

  def errors
    s = @results.pgsql.exec('SELECT errors FROM result WHERE id = $1', [@id])[0]['errors']
    s.nil? ? s : s.to_i
  end

  def stdout
    @results.pgsql.exec('SELECT stdout FROM result WHERE id = $1', [@id])[0]['stdout']
  end

  def exit
    @results.pgsql.exec('SELECT exit FROM result WHERE id = $1', [@id])[0]['exit'].to_i
  end

  def msec
    @results.pgsql.exec('SELECT msec FROM result WHERE id = $1', [@id])[0]['msec'].to_i
  end

  def to_json(*_args)
    {
      id: @id,
      stdout:
    }
  end
end
