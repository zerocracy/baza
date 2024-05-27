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
require_relative 'receipt'

# Account of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Account
  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def each
    @human.pgsql.exec('SELECT * FROM receipt WHERE human = $1', [@human.id]).each do |row|
      yield Veil.new(
        Baza::Receipt.new(self, row['id'].to_i),
        job_id: row['job'].to_i,
        zents: row['zents'].to_i,
        summary: row['summary'],
        created: Time.parse(row['created'])
      )
    end
  end

  def balance
    @human.pgsql.exec(
      'SELECT SUM(zents) FROM receipt WHERE human = $1',
      [@human.id]
    )[0]['sum'].to_i
  end

  def add(zents, summary, job = nil)
    @human.pgsql.exec(
      'INSERT INTO receipt (human, zents, summary, job) VALUES ($1, $2, $3, $4) RETURNING id',
      [@human.id, zents, summary, job]
    ).empty?
  end
end
