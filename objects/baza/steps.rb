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

# All invocations (steps) of a job.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Steps
  attr_reader :job

  def initialize(job)
    @job = job
  end

  def pgsql
    @job.pgsql
  end

  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    rows = pgsql.exec(
      [
        'SELECT invocation.*,',
        'swarm.name AS swarm, swarm.id AS swarm_id',
        'FROM invocation',
        'JOIN swarm ON swarm.id = invocation.swarm',
        'WHERE job = $1',
        'ORDER BY invocation.id ASC',
        "OFFSET #{offset.to_i}"
      ],
      [job.id]
    )
    rows.each do |row|
      r = {
        id: row['id'].to_i,
        code: row['code'].to_i,
        msec: row['msec'].to_i,
        version: row['version'],
        name: row['name'],
        swarm: row['swarm'],
        swarm_id: row['swarm_id'].to_i,
        stdout: row['stdout'],
        created: Time.parse(row['created'])
      }
      yield r
    end
  end
end
