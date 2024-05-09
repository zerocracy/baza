# frozen_string_literal: true

# Copyright (c) 2009-2024 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
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
  attr_reader :id

  def initialize(job, id)
    @job = job
    @id = id
  end

  def created
    Time.parse(@job.pgsql.exec('SELECT created FROM result WHERE id = $1', [@id])[0]['created'])
  end

  def stdout
    @job.pgsql.exec('SELECT stdout FROM result WHERE id = $1', [@id])[0]['stdout']
  end

  def exit
    @job.pgsql.exec('SELECT exit FROM result WHERE id = $1', [@id])[0]['exit'].to_i
  end

  def msec
    @job.pgsql.exec('SELECT msec FROM result WHERE id = $1', [@id])[0]['msec'].to_i
  end

  def to_json
    {
      id: @id,
      stdout: stdout
    }
  end
end
