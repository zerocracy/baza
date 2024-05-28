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

require 'unpiercable'
require_relative 'token'

# Jobs of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Jobs
  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def empty?
    @human.pgsql.exec(
      'SELECT job.id FROM job JOIN token ON token.id = job.token WHERE token.human = $1',
      [@human.id]
    ).empty?
  end

  def each(cnd = '')
    return to_enum(__method__, cnd) unless block_given?
    sql =
      'SELECT job.*, ' \
      'result.id AS rid, result.uri2, result.stdout, result.exit, result.msec FROM job ' \
      'JOIN token ON token.id = job.token ' \
      'LEFT JOIN result ON result.job = job.id ' \
      "WHERE token.human = $1 #{cnd.empty? ? cnd : "AND #{cnd}"}"
    @human.pgsql.exec(sql, [@human.id]).each do |row|
      job = Baza::Job.new(self, row['id'].to_i)
      yield Unpiercable.new(
        job,
        created: Time.parse(row['created']),
        name: row['name'],
        uri1: row['uri1'],
        finished?: !row['rid'].nil?,
        result: Unpiercable.new(
          Baza::Result.new(job, row['rid'].to_i),
          uri2: row['uri2'],
          exit: row['exit'].to_i,
          empty?: row['uri2'].nil?,
          stdout: row['stdout']
        )
      )
    end
  end

  def get(id)
    raise 'Job ID must be an integer' unless id.is_a?(Integer)
    each("job.id = #{id}").to_a[0]
  end

  def recent(name)
    rows = @human.pgsql.exec(
      'SELECT job.id FROM job ' \
      'JOIN token ON token.id = job.token ' \
      'WHERE token.human = $1 ' \
      'ORDER BY job.created DESC ' \
      'LIMIT 1',
      [@human.id]
    )
    raise Baza::Urror, "No job by the name '#{name}' found" if rows.empty?
    Baza::Job.new(self, rows[0]['id'].to_i)
  end
end
