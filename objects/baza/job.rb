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
  attr_reader :id, :jobs

  def initialize(jobs, id)
    @jobs = jobs
    raise 'Job ID must be an integer' unless id.is_a?(Integer)
    @id = id
  end

  def pgsql
    @jobs.pgsql
  end

  # Delete the data of the job, that take space.
  def expire!(fbs)
    raise Baza::Urror, 'The job is already expired' if expired?
    @jobs.pgsql.transaction do |t|
      t.exec('UPDATE job SET expired = now() WHERE id = $1', [@id])
      t.exec('UPDATE result SET expired = now() WHERE job = $1', [@id])
      t.exec('UPDATE result SET stdout = \'The stdout has been removed\' WHERE job = $1', [@id])
    end
    fbs.delete(uri1)
    fbs.delete(result.uri2) if finished?
    @to_json = nil
  end

  # Is it expired and doesn't have any data anymore?
  def expired?
    to_json[:expired]
  end

  # Finish the job, create a RESULT for it and a RECEIPT.
  # @param [String] uri2 The location of the factbase produced by the job (URI in AWS), or NIL
  # @param [String] stdout The full log of the job (at the console)
  # @param [Integer] exit The exit code of the job (zero means success)
  # @param [Integer] msec The amount of milliseconds the job took
  # @param [Integer] size The size of the output factbase file
  # @param [Integer] errors How many errors found in the summary?
  # @return [Baza::Result] The result just created
  def finish!(uri2, stdout, exit, msec, size = nil, errors = nil)
    raise Baza::Urror, 'Exit code is nil' if exit.nil?
    raise Baza::Urror, 'Exit code must be a Number' unless exit.is_a?(Integer)
    raise Baza::Urror, 'Milliseconds is nil' if msec.nil?
    raise Baza::Urror, 'Milliseconds must be a Number' unless msec.is_a?(Integer)
    raise Baza::Urror, 'STDOUT is nil' if stdout.nil?
    raise Baza::Urror, 'STDOUT must be a String' unless stdout.is_a?(String)
    raise Baza::Urror, 'Size must be positive' unless size.nil? || size.positive?
    raise Baza::Urror, 'Number of errors cannot be negative' unless errors.nil? || !errors.negative?
    raise Baza::Urror, 'When exit code is zero, size is mandatory' if exit.zero? && size.nil?
    raise Baza::Urror, 'When exit code is zero, errors count is mandatory' if exit.zero? && errors.nil?
    summary =
      "Job ##{id} #{exit.zero? ? 'completed' : "failed (#{exit})"} " \
      "in #{msec}ms, #{stdout.split("\n").size} lines in stdout"
    @jobs.pgsql.transaction do |t|
      t.exec(
        'INSERT INTO receipt (human, zents, summary, job) VALUES ($1, $2, $3, $4) RETURNING id',
        [@jobs.human.id, -msec, summary, id]
      )[0]['id'].to_i
      @jobs.human.results.get(
        t.exec(
          [
            'INSERT INTO result (job, uri2, stdout, exit, msec, size, errors) ',
            'VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id'
          ],
          [id, uri2, stdout, exit, msec, size, errors]
        )[0]['id'].to_i
      )
    end
    @to_json = nil
  end

  def secrets
    @jobs.pgsql.exec(
      [
        'SELECT secret.* FROM secret ',
        'JOIN token ON secret.human = token.human ',
        'JOIN job ON token.id = job.token ',
        'WHERE secret.name = $1'
      ],
      [name.downcase]
    ).each.to_a
  end

  def valve
    Valve.new(self)
  end

  def created
    to_json[:created]
  end

  def when_locked
    to_json[:when_locked]
  end

  def lock_owner
    to_json[:lock_owner]
  end

  def finished?
    to_json[:finished]
  end

  def name
    to_json[:name]
  end

  def agent
    to_json[:agent]
  end

  def taken
    to_json[:taken]
  end

  def token
    @jobs.human.tokens.get(to_json[:token])
  end

  def uri1
    to_json[:uri1]
  end

  def size
    to_json[:size]
  end

  def errors
    to_json[:errors]
  end

  def result
    rows = @jobs.pgsql.exec('SELECT id FROM result WHERE job = $1', [@id])
    raise Baza::Urror, 'There is no result yet' if rows.empty?
    @jobs.human.results.get(rows[0]['id'].to_i)
  end

  def to_json(*_args)
    @to_json ||=
      begin
        row = @jobs.pgsql.exec(
          [
            'SELECT job.*, result.id AS rid, ',
            'lock.created AS when_locked, lock.owner AS lock_owner',
            'FROM job',
            'JOIN token ON token.id = job.token',
            'LEFT JOIN result ON result.job = job.id',
            'LEFT JOIN lock ON lock.name = job.name AND lock.human = token.human',
            'WHERE job.id = $1'
          ],
          [@id]
        ).first
        {
          id: @id,
          name: row['name'].downcase,
          created: Time.parse(row['created']),
          uri1: row['uri1'],
          token: row['token'].to_i,
          taken: row['taken'],
          when_locked: row['when_locked'].nil? ? nil : Time.parse(row['when_locked']),
          lock_owner: row['lock_owner'],
          size: row['size'].to_i,
          errors: row['errors'].to_i,
          agent: row['agent'],
          finished: !row['rid'].nil?,
          expired: !row['expired'].nil?
        }
      end
  end

  # A valve of a job.
  class Valve
    def initialize(job)
      @job = job
    end

    def enter(badge, why, &)
      @job.jobs.human.valves.enter(@job.name, badge, why, &)
    end
  end
end
