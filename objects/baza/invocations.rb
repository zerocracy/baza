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

# All invocations of a swarm.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Invocations
  attr_reader :swarm

  def initialize(swarm)
    @swarm = swarm
  end

  def pgsql
    @swarm.pgsql
  end

  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    rows = @swarm.pgsql.exec(
      [
        'SELECT * FROM invocation',
        'WHERE swarm = $1',
        'ORDER BY created DESC',
        "OFFSET #{offset.to_i}"
      ],
      [@swarm.id]
    )
    rows.each do |row|
      r = {
        id: row['id'].to_i,
        job: row['job'].to_i,
        stdout: row['stdout'],
        created: Time.parse(row['created'])
      }
      yield r
    end
  end

  # Register new invocation.
  #
  # @param [Baza::Job] job The ID of the job
  # @param [String] stdout The output
  # @return [Integer] The ID of the added invocation
  def register(job, stdout)
    raise Baza::Urror, 'The "job" cannot be NIL' if job.nil?
    raise Baza::Urror, 'The "stdout" cannot be NIL' if stdout.nil?
    @swarm.pgsql.exec(
      'INSERT INTO invocation (swarm, job, stdout) VALUES ($1, $2, $3) RETURNING id',
      [@swarm.id, job.id, stdout]
    )[0]['id'].to_i
  end
end
