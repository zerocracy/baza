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

require 'securerandom'
require 'veil'

# Tokens of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Tokens
  attr_reader :human

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def add(name)
    raise 'Name is nil' if name.nil?
    raise Baza::Urror, 'Name is too long (>32)' if name.length > 32
    raise Baza::Urror, 'Name can\'t be empty' if name.empty?
    total = actives
    raise Baza::Urror, "Too many active tokens already (#{total})" if total >= 8
    raise Baza::Urror, 'Token with this name already exists' if exists?(name)
    uuid = SecureRandom.uuid
    rows = pgsql.exec(
      'INSERT INTO token (human, name, text) VALUES ($1, $2, $3) RETURNING id',
      [@human.id, name, uuid]
    )
    get(rows[0]['id'].to_i)
  end

  def empty?
    pgsql.exec('SELECT id FROM token WHERE human = $1', [@human.id]).empty?
  end

  def size
    pgsql.exec('SELECT COUNT(id) AS c FROM token WHERE human = $1', [@human.id])[0]['c'].to_i
  end

  def actives
    pgsql.exec('SELECT COUNT(id) AS c FROM token WHERE human = $1 AND active', [@human.id])[0]['c'].to_i
  end

  def each(offset: 0)
    q =
      'SELECT token.*, COUNT(job.id) AS jobs_count FROM token ' \
      'LEFT JOIN job ON job.token = token.id ' \
      'WHERE human=$1 ' \
      'GROUP BY token.id ' \
      'ORDER BY active DESC, created DESC ' \
      "OFFSET #{offset.to_i}"
    pgsql.exec(q, [@human.id]).each do |row|
      yield Veil.new(
        get(row['id'].to_i),
        active?: row['active'] == 't',
        name: row['name'],
        text: row['text'],
        jobs_count: row['jobs_count']
      )
    end
  end

  def to_a
    array = []
    each do |t|
      array << t
    end
    array
  end

  def exists?(name)
    !pgsql.exec('SELECT id FROM token WHERE human = $1 AND name = $2', [@human.id, name]).empty?
  end

  def find(text)
    rows = pgsql.exec('SELECT id FROM token WHERE text = $1', [text])
    raise Baza::Urror, 'Token not found' if rows.empty?
    get(rows[0]['id'].to_i)
  end

  def get(id)
    rows = pgsql.exec('SELECT * FROM token WHERE id = $1', [id])
    raise Baza::Urror, "Token ##{id} not found" if rows.empty?
    row = rows[0]
    require_relative 'token'
    token = Baza::Token.new(self, id)
    Veil.new(
      token,
      active: row['active'] == 't',
      name: row['name'],
      text: row['text'],
      created: Time.parse(row['created'])
    )
  end
end
