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

# Jobs of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Jobs
  attr_reader :human

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def empty?
    pgsql.exec(
      'SELECT job.id FROM job JOIN token ON token.id = job.token WHERE token.human = $1',
      [@human.id]
    ).empty?
  end

  def start(token, name, uri1)
    get(
      pgsql.exec(
        'INSERT INTO job (token, name, uri1) VALUES ($1, $2, $3) RETURNING id',
        [token, name, uri1]
      )[0]['id'].to_i
    )
  end

  def each(name: nil, offset: 0)
    sql =
      'SELECT job.*, token.id AS tid, token.name AS token_name, ' \
      'result.id AS rid, result.uri2, result.stdout, result.exit, result.msec FROM job ' \
      'JOIN token ON token.id = job.token ' \
      'LEFT JOIN result ON result.job = job.id ' \
      'WHERE token.human = $1 ' \
      "#{name.nil? ? '' : 'AND job.name = $2'} " \
      'ORDER BY created DESC ' \
      "OFFSET #{offset.to_i}"
    args = [@human.id]
    args << name unless name.nil?
    pgsql.exec(sql, args).each do |row|
      yield Veil.new(
        get(row['id'].to_i),
        id: row['id'].to_i,
        created: Time.parse(row['created']),
        name: row['name'],
        uri1: row['uri1'],
        finished?: !row['rid'].nil?,
        expired?: !row['expired'].nil?,
        token: Veil.new(
          @human.tokens.get(row['tid'].to_i),
          name: row['token_name']
        ),
        result: Veil.new(
          @human.results.get(row['rid'].to_i),
          id: row['rid'].to_i,
          uri2: row['uri2'],
          msec: row['msec'].to_i,
          exit: row['exit'].to_i,
          empty?: row['uri2'].nil?,
          stdout: row['stdout']
        )
      )
    end
  end

  def get(id)
    raise 'Job ID must be an integer' unless id.is_a?(Integer)
    require_relative 'job'
    Baza::Job.new(self, id)
  end

  def name_exists?(name)
    !pgsql.exec(
      'SELECT job.id FROM job ' \
      'JOIN token ON token.id = job.token ' \
      'WHERE token.human = $1 AND job.name = $2 AND expired IS NULL ' \
      'LIMIT 1',
      [@human.id, name]
    ).empty?
  end

  def recent(name)
    rows = pgsql.exec(
      'SELECT job.id FROM job ' \
      'JOIN token ON token.id = job.token ' \
      'WHERE token.human = $1 AND job.name = $2 AND expired IS NULL ' \
      'ORDER BY job.created DESC ' \
      'LIMIT 1',
      [@human.id, name]
    )
    raise Baza::Urror, "No job by the name '#{name}' found" if rows.empty?
    get(rows[0]['id'].to_i)
  end
end
