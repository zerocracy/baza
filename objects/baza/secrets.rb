# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2025 Zerocracy
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
class Baza::Secrets
  attr_reader :human

  SHAREABLE = %w[ZEROCRAT_TOKEN ANTHROPIC_KEY].freeze

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def empty?
    pgsql.exec(
      'SELECT id FROM secret WHERE human = $1',
      [@human.id]
    ).empty?
  end

  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    rows = pgsql.exec(
      [
        'SELECT secret.*, COUNT(job.id) AS jobs FROM secret',
        'LEFT JOIN job ON job.name = secret.name',
        'WHERE human = $1',
        'GROUP BY secret.id',
        'ORDER BY secret.key',
        "OFFSET #{offset.to_i}"
      ],
      [@human.id]
    )
    rows.each do |row|
      s = {
        id: row['id'].to_i,
        name: row['name'],
        key: row['key'],
        value: row['value'],
        created: Time.parse(row['created']),
        jobs: row['jobs'].to_i,
        shareable: SHAREABLE.include?(row['key'].upcase)
      }
      yield s
    end
  end

  def exists?(name, key)
    !pgsql.exec(
      'SELECT id FROM secret WHERE human = $1 AND name = $2 AND key = $3',
      [@human.id, name.downcase, key]
    ).empty?
  end

  def add(name, key, value)
    raise Baza::Urror, 'The name cannot be empty' if name.empty?
    raise Baza::Urror, 'The name is not valid' unless name.match?(/^[a-z0-9]+$/)
    raise Baza::Urror, 'The key cannot be empty' if key.empty?
    raise Baza::Urror, 'The key is not valid' unless key.match?(/^[a-zA-Z0-9_]+$/)
    raise Baza::Urror, 'The value cannot be empty' if value.empty?
    raise Baza::Urror, 'The value is not ASCII' unless value.ascii_only?
    raise Baza::Urror, 'A secret with these name+key already exists' if exists?(name, key)
    id = pgsql.exec(
      'INSERT INTO secret (human, name, key, value) VALUES ($1, $2, $3, $4) RETURNING id',
      [@human.id, name.downcase, key, value]
    )[0]['id'].to_i
    @human.notify("🥕 Secret with ID #{id} has been successfully added.")
    id
  end

  def remove(id)
    pgsql.exec(
      'DELETE FROM secret WHERE id = $1 AND human = $2',
      [id, @human.id]
    )
  end
end
