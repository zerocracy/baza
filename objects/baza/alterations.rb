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

# Alterations of a human.
#
# Every alteration is a Ruby script that is supposed to be executed
# as a judge on a Factbase of the job.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Alterations
  attr_reader :human

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def empty?
    pgsql.exec(
      'SELECT id FROM alteration WHERE human = $1',
      [@human.id]
    ).empty?
  end

  def each
    return to_enum(__method__) unless block_given?
    rows = pgsql.exec(
      [
        'SELECT alteration.*, COUNT(job.id) AS jobs FROM alteration',
        'LEFT JOIN job ON job.name = alteration.name',
        'WHERE alteration.human = $1',
        'GROUP BY alteration.id',
        'ORDER BY alteration.created DESC'
      ],
      [@human.id]
    )
    rows.each do |row|
      s = {
        id: row['id'].to_i,
        name: row['name'],
        script: row['script'],
        created: Time.parse(row['created']),
        jobs: row['jobs'].to_i
      }
      yield s
    end
  end

  def add(name, script)
    raise Baza::Urror, 'The name cannot be empty' if name.empty?
    raise Baza::Urror, 'The name is not valid' unless name.match?(/^[a-z0-9]+$/)
    raise Baza::Urror, 'The script cannot be empty' if script.empty?
    raise Baza::Urror, 'The script is not ASCII' unless script.ascii_only?
    pgsql.exec(
      'INSERT INTO alteration (human, name, script) VALUES ($1, $2, $3) RETURNING id',
      [@human.id, name.downcase, script]
    )[0]['id'].to_i
  end

  def remove(id)
    pgsql.exec(
      'DELETE FROM alteration WHERE id = $1 AND human = $2',
      [id, @human.id]
    )
  end
end
