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

  # Iterate over invocations.
  # @param [Integer] offset The offset to start with
  # @yield [Hash] Data about an invocation
  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    rows = pgsql.exec(
      [
        'SELECT invocation.*, job.name, swarm.name AS swarm FROM invocation',
        'LEFT JOIN job ON job.id = invocation.job',
        'JOIN swarm ON swarm.id = invocation.swarm',
        'WHERE swarm = $1',
        'ORDER BY invocation.created DESC',
        "OFFSET #{offset.to_i}"
      ],
      [@swarm.id]
    )
    rows.each do |row|
      r = {
        id: row['id'].to_i,
        code: row['code'].to_i,
        msec: row['msec'].to_i,
        version: row['version'],
        job: row['job']&.to_i,
        name: row['name'],
        swarm: row['swarm'],
        stdout: row['stdout'],
        created: Time.parse(row['created'])
      }
      yield r
    end
  end

  # Register new invocation.
  #
  # @param [String] stdout The output
  # @param [Integer] code The code (zero means success)
  # @param [Integer] msec How long it took (in milliseconds)
  # @param [Baza::Job|nil] job The ID of the job
  # @param [String] version The version of the software in the AWS Lambda
  # @return [Integer] The ID of the added invocation
  def register(stdout, code, msec, job, version)
    raise Baza::Urror, 'The "code" must be an integer' unless code.is_a?(Integer)
    raise Baza::Urror, 'The "msec" must be an integer' unless msec.is_a?(Integer)
    raise Baza::Urror, 'The "stdout" cannot be NIL' if stdout.nil?
    raise Baza::Urror, 'The "version" cannot be NIL' if version.nil?
    id = pgsql.exec(
      'INSERT INTO invocation (swarm, code, msec, version, job, stdout) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id',
      [@swarm.id, code, msec, version, job.nil? ? nil : job.id, stdout]
    )[0]['id'].to_i
    unless code.zero?
      @swarm.swarms.human.notify(
        "⚠️ The [swarm ##{@swarm.id}](//swarms/#{@swarm.id}/releases) (\"`#{@swarm.name}`\")",
        "just failed after #{msec} milliseconds of work,",
        "at the invocation [##{id}](//invocation/#{id})",
        unless job.nil?
          [
            "for the job [##{job.id}](//jobs/#{job.id}) ",
            "(`#{job.name}`) of @#{job.jobs.human.github}"
          ].join
        end,
        "(exit code is `#{code}`, there are #{stdout.split("\n").count} lines in the stdout).",
        unless version == Baza::VERSION
          [
            "The version of the swarm is `#{version}`, ",
            "while the version of Baza is `#{Baza::VERSION}` — ",
            'maybe this is the root cause of the failure.'
          ].join
        end
      )
    end
    id
  end
end
