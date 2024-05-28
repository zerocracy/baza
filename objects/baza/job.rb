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

require_relative 'result'

# One job.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Job
  attr_reader :id

  def initialize(jobs, id)
    @jobs = jobs
    raise 'Job ID must be an integer' unless id.is_a?(Integer)
    @id = id
  end

  def pgsql
    @jobs.pgsql
  end

  def finish(factbase, stdout, exit, msec)
    raise Baza::Urror, 'Exit code must a Number' unless exit.is_a?(Integer)
    raise Baza::Urror, 'Milliseconds must a Number' unless msec.is_a?(Integer)
    @jobs.pgsql.exec(
      'INSERT INTO result (job, factbase, stdout, exit, msec) VALUES ($1, $2, $3, $4, $5)',
      [@id, factbase, stdout, exit, msec]
    )
  end

  def created
    rows = @jobs.pgsql.exec('SELECT created FROM job WHERE id = $1', [@id])
    raise Baza::Urror, "There is no job ##{@id}" if rows.empty?
    Time.parse(rows[0]['created'])
  end

  def finished?
    !@jobs.pgsql.exec('SELECT id FROM result WHERE job = $1', [@id]).empty?
  end

  def name
    @jobs.pgsql.exec('SELECT name FROM job WHERE id = $1', [@id])[0]['name']
  end

  def fb
    @jobs.pgsql.exec('SELECT factbase FROM job WHERE id = $1', [@id])[0]['factbase']
  end

  def result
    rows = @jobs.pgsql.exec(
      'SELECT * FROM result WHERE job = $1',
      [@id]
    )
    raise Baza::Urror, 'There is no result yet' if rows.empty?
    Baza::Result.new(self, rows[0]['id'].to_i)
  end

  def to_json(*_args)
    {
      id: @id,
      finished: finished?
    }
  end
end
