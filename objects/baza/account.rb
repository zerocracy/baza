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

require 'veil'
require_relative 'zents'

# Account of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Account
  attr_reader :human

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def bars(days: 12 * 7)
    pgsql.exec(
      [
        'SELECT SUM(CASE WHEN zents > 0 THEN zents ELSE 0 END) AS debit,',
        'SUM(CASE WHEN zents < 0 THEN -zents ELSE 0 END) AS credit,',
        "to_char(created, 'YY.WW') AS week",
        'FROM receipt',
        'WHERE human = $1',
        "AND created > NOW() - INTERVAL '#{days.to_i} DAYS'",
        'GROUP BY week',
        'ORDER BY week'
      ],
      [@human.id]
    ).map { |row| { week: row['week'], debit: row['debit'].to_i, credit: row['credit'].to_i } }
  end

  def each(offset: 0)
    q = [
      'SELECT receipt.*, job.name AS jname FROM receipt',
      'LEFT JOIN job ON receipt.job = job.id',
      'WHERE receipt.human = $1',
      'ORDER BY receipt.created DESC',
      "OFFSET #{offset.to_i}"
    ]
    pgsql.exec(q, [@human.id]).each do |row|
      yield Veil.new(
        get(row['id'].to_i),
        id: row['id'].to_i,
        job_id: row['job']&.to_i,
        job_name: row['jname']&.to_i,
        zents: row['zents'].to_i,
        summary: row['summary'],
        created: Time.parse(row['created'])
      )
    end
  end

  # Get total current balance of the human.
  def balance
    pgsql.exec(
      'SELECT SUM(zents) FROM receipt WHERE human = $1',
      [@human.id]
    )[0]['sum'].to_i
  end

  # Add a new receipt for a human, not attached to a job.
  # @param [Integer] amount How many zents to add to the account
  # @param [String] summary The description of the transaction
  # @param [Time] created The time of the transaction
  # @return [Integer] The ID of the transaction
  def top_up(amount, summary, created: Time.now)
    id = pgsql.exec(
      'INSERT INTO receipt (human, zents, summary, created) VALUES ($1, $2, $3, $4) RETURNING id',
      [@human.id, amount, summary, created]
    )[0]['id']
    @human.notify(
      "🍏 Because we love you, we topped up your account by #{amount.zents}.",
      "Now, the balance is #{balance.zents}. Thanks for using Zerocracy!"
    )
    id
  end

  # Get a single receipt by ID.
  def get(id)
    raise 'Receipt ID must be an integer' unless id.is_a?(Integer)
    require_relative 'receipt'
    Baza::Receipt.new(self, id)
  end
end
