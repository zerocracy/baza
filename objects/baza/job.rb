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
class Baza::Job
  attr_reader :id

  def initialize(jobs, id)
    @jobs = jobs
    @id = id
  end

  def finish(stdout, exit, msec)
    raise Baza::Urror, 'Exit code must a Number' unless exit.is_a?(Integer)
    raise Baza::Urror, 'Milliseconds must a Number' unless msec.is_a?(Integer)
    @jobs.pgsql.exec(
      'INSERT INTO log (job, stdout, exit, msec) VALUES ($1, $2, $3, $4)',
      [@id, stdout, exit, msec]
    )
  end

  def finished?
    !@jobs.pgsql.exec('SELECT FROM log WHERE job = $1', [@id]).empty?
  end
end
