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
require 'unpiercable'
require 'veil'
require_relative 'token'

# Tokens of a user.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Tokens
  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def add(name)
    raise Baza::Urror, 'Name is too long (>32)' if name.length > 32
    total = size
    raise Baza::Urror, "Too many tokens already (#{total})" if total >= 8
    raise Baza::Urror, 'Token with this name already exists' if exists?(name)
    uuid = SecureRandom.uuid
    rows = @human.pgsql.exec(
      'INSERT INTO token (human, name, text) VALUES ($1, $2, $3) RETURNING id',
      [@human.id, name, uuid]
    )
    id = rows[0]['id'].to_i
    Baza::Token.new(self, id)
  end

  def empty?
    @human.pgsql.exec('SELECT id FROM token WHERE human = $1', [@human.id]).empty?
  end

  def size
    @human.pgsql.exec('SELECT COUNT(id) AS c FROM token WHERE human = $1', [@human.id])[0]['c'].to_i
  end

  def each
    @human.pgsql.exec('SELECT * FROM token WHERE human=$1', [@human.id]).each do |row|
      yield Unpiercable.new(
        Baza::Token.new(self, row['id'].to_i),
        active?: row['active'] == 't',
        name: row['name'],
        text: row['text']
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
    !@human.pgsql.exec('SELECT id FROM token WHERE human = $1 AND name = $2', [@human.id, name]).empty?
  end

  def find(text)
    rows = @human.pgsql.exec('SELECT id FROM token WHERE text = $1', [text])
    raise Baza::Urror, 'Token not found' if rows.empty?
    Baza::Token.new(self, rows[0]['id'].to_i)
  end

  def get(id)
    rows = @human.pgsql.exec('SELECT * FROM token WHERE id = $1', [id])
    raise Baza::Urror, "Token ##{id} not found" if rows.empty?
    row = rows[0]
    Veil.new(
      Baza::Token.new(self, id),
      active: row['active'] == 't',
      name: row['name'],
      text: row['text']
    )
  end
end
