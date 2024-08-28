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

# Locks of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Locks
  attr_reader :human

  class Busy < Baza::Urror; end

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def empty?
    pgsql.exec(
      'SELECT id FROM lock WHERE human = $1',
      [@human.id]
    ).empty?
  end

  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    pgsql.exec(
      [
        'SELECT lock.*, COUNT(job.id) AS jobs FROM lock',
        'LEFT JOIN job ON job.name = lock.name',
        'WHERE human = $1',
        'GROUP BY lock.id',
        'ORDER BY lock.created DESC',
        "OFFSET #{offset.to_i}"
      ],
      [@human.id]
    ).each do |row|
      lk = {
        id: row['id'].to_i,
        created: Time.parse(row['created']),
        name: row['name'],
        owner: row['owner'],
        jobs: row['jobs'].to_i
      }
      yield lk
    end
  end

  def locked?(name)
    !pgsql.exec(
      'SELECT id FROM lock WHERE human = $1 AND name = $2',
      [@human.id, name.downcase]
    ).empty?
  end

  def lock(name, owner, ip)
    unless @human.account.balance.positive? || @human.extend(Baza::Human::Roles).tester?
      raise Baza::Urror, 'The balance is negative, you cannot lock jobs'
    end
    raise Busy, "The #{name} job is busy" if @human.jobs.busy?(name)
    begin
      pgsql.exec(
        [
          'INSERT INTO lock (human, name, owner, ip) ',
          'VALUES ($1, $2, $3, %4) ',
          'ON CONFLICT (human, name, owner) DO UPDATE SET owner = lock.owner'
        ],
        [@human.id, name.downcase, owner, ip]
      )
    rescue PG::UniqueViolation
      raise Busy, "The '#{name}' lock is occupied by another owner, '#{owner}' can't get it now"
    end
  end

  def unlock(name, owner)
    pgsql.exec(
      'DELETE FROM lock WHERE human = $1 AND owner = $3 AND name = $2',
      [@human.id, name.downcase, owner]
    )
  end

  def delete(id)
    pgsql.exec(
      'DELETE FROM lock WHERE id = $1 AND human = $2',
      [id, @human.id]
    )
  end
end
