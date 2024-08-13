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

require_relative 'urror'
require_relative 'human'

# Durables of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Durables
  attr_reader :human

  def initialize(human, fbs)
    @human = human
    @fbs = fbs
  end

  def pgsql
    @human.pgsql
  end

  def empty?
    pgsql.exec(
      'SELECT id FROM durable WHERE human = $1',
      [human.id]
    ).empty?
  end

  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    rows = pgsql.exec(
      [
        'SELECT durable.*, COUNT(job.id) AS jobs FROM durable',
        'LEFT JOIN job ON job.name = durable.jname',
        'WHERE human = $1',
        'GROUP BY durable.id',
        'ORDER BY durable.file',
        "OFFSET #{offset.to_i}"
      ],
      [human.id]
    )
    rows.each do |row|
      d = {
        id: row['id'].to_i,
        jname: row['jname'],
        file: row['file'],
        uri: row['uri'],
        busy: row['busy'],
        size: row['size'].to_i,
        created: Time.parse(row['created']),
        jobs: row['jobs'].to_i,
        shareable: row['file'].start_with?('@')
      }
      yield d
    end
  end

  # Lock one durable.
  #
  # @param [Integer] id The ID of the durable to lock
  # @param [String] owner The owner of the lock
  def get(id)
    require_relative 'durable'
    Baza::Durable.new(@human, @fbs, id)
  end

  # Start a new durable (using the file provided) or return an already existing one.
  #
  # @param [String] jname The name of a job
  # @param [String] file The file of the durable
  # @param [String] file The file where to get start content
  # @return [Integer] The ID of the durable created or found
  def place(jname, file, source)
    raise Baza::Urror, "The name '#{jname}' is not valid, make it low-case" unless jname.match?(/^[a-z0-9-]+$/)
    raise Baza::Urror, "The file name '#{file}' is not valid" unless file.match?(/^@?[A-Za-z0-9-\.]+$/)
    raise Baza::Urror, "The file '#{source}' doesn't exist" unless File.exist?(source)
    get(
      pgsql.transaction do |t|
        t.exec('LOCK human IN EXCLUSIVE MODE')
        rows = t.exec(
          [
            'SELECT id FROM durable',
            'WHERE (human = $1 AND jname = $2 AND file = $3)',
            "OR (file LIKE '@%' AND file = $3)"
          ],
          [human.id, jname, file]
        )
        if rows.empty?
          if file.start_with?('@') && !@human.extend(Baza::Human::Roles).admin?
            raise Baza::Urror, "You cannot place a new durable with the name '#{file}', the prefix is admin-only"
          end
          t.exec(
            'INSERT INTO durable (human, jname, file, uri, size) VALUES ($1, $2, $3, $4, $5) RETURNING id',
            [human.id, jname, file, @fbs.save(source), File.size(source)]
          ).first['id'].to_i
        else
          rows.first['id'].to_i
        end
      end
    )
  end
end
