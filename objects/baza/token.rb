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

require_relative 'job'

# One token.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Token
  attr_reader :id, :tokens

  def initialize(tokens, id)
    @tokens = tokens
    @id = id
  end

  def pgsql
    @tokens.pgsql
  end

  def human
    @tokens.human.humans.get(
      @tokens.pgsql.exec('SELECT human FROM token WHERE id = $1', [@id])[0]['human'].to_i
    )
  end

  def deactivate!
    raise Baza::Urror, 'This token cannot be deactivated' if text == Baza::Tokens::TESTER
    rows = @tokens.pgsql.exec(
      'UPDATE token SET active = false WHERE id = $1 AND human = $2 RETURNING id',
      [@id, @tokens.human.id]
    )
    raise Baza::Urror, "The token ##{@id} wasn't deactivated" if rows.empty?
    @to_json = nil
  end

  def delete!
    raise Baza::Urror, 'This token cannot be deactivated' if text == Baza::Tokens::TESTER
    rows = @tokens.pgsql.exec(
      'DELETE FROM token WHERE id = $1 AND human = $2 RETURNING id',
      [@id, @tokens.human.id]
    )
    raise Baza::Urror, "The token ##{@id} wasn't deactivated" if rows.empty?
    @to_json = nil
  end

  # Start a new job.
  # @param [String] name The name of the job
  # @param [String] uri1 The URI of the factbase file (usually in AWS S3)
  # @param [Integer] size The size of the factbase file, in bytes
  # @param [Integer] errors How many errors are in the factbase file
  # @param [String] agent HTTP "user-agent" header of the sender of the file
  # @param [Array<String>] meta List of metas (in "key=value" format)
  # @param [String] ip The IP address of the job submitter
  # @return [Baza::Job] The job just started
  def start(name, uri1, size, errors, agent, meta, ip)
    raise Baza::Urror, 'The token is inactive' unless active?
    unless human.account.balance.positive? || human.extend(Baza::Human::Roles).tester?
      raise Baza::Urror, 'The balance is negative, you cannot post new jobs'
    end
    @tokens.human.jobs.start(@id, name, uri1, size, errors, agent, meta, ip)
  end

  def active?
    to_json[:active]
  end

  def created
    to_json[:created]
  end

  def name
    to_json[:name]
  end

  def text
    to_json[:text]
  end

  def jobs
    to_json[:jobs]
  end

  def to_json(*_args)
    @to_json ||=
      begin
        row = pgsql.exec(
          [
            'SELECT token.*, COUNT(job.id) AS jobs FROM token',
            'LEFT JOIN job ON job.token = token.id',
            'WHERE token.id = $1 AND token.human = $2',
            'GROUP BY token.id'
          ],
          [@id, @tokens.human.id]
        ).first
        raise Baza::Urror, "There is no token ##{@id} for user ##{@tokens.human.id}" if row.nil?
        {
          id: @id,
          name: row['name'],
          text: row['text'],
          active: row['active'] == 't',
          jobs: row['jobs'].to_i,
          created: Time.parse(row['created'])
        }
      end
  end
end
