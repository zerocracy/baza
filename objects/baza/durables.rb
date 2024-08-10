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

require 'loog'
require 'fileutils'

# Durables of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Durables
  attr_reader :human

  SHAREABLE = %w[eva-model].freeze

  # When can't lock a durable.
  class Busy < StandardError; end

  def initialize(human, fbs, loog: Loog::NULL)
    @human = human
    @fbs = fbs
    @loog = loog
  end

  def pgsql
    @human.pgsql
  end

  def empty?(human)
    pgsql.exec(
      'SELECT id FROM durable WHERE human = $1',
      [human.id]
    ).empty?
  end

  def each(human)
    return to_enum(__method__) unless block_given?
    rows = pgsql.exec(
      [
        'SELECT durable.*, COUNT(job.id) AS jobs FROM durable',
        'LEFT JOIN job ON job.name = durable.jname',
        'WHERE human = $1',
        'GROUP BY durable.id',
        'ORDER BY durable.directory'
      ],
      [human.id]
    )
    rows.each do |row|
      d = {
        id: row['id'].to_i,
        jname: row['jname'],
        directory: row['directory'],
        uri: row['uri'],
        busy: row['busy'],
        created: Time.parse(row['created']),
        jobs: row['jobs'].to_i,
        shareable: SHAREABLE.include?(row['directory'].downcase)
      }
      yield d
    end
  end

  # Lock one durable.
  #
  # @param [Integer] id The ID of the durable to lock
  # @param [String] owner The owner of the lock
  def lock(id, owner)
    rows = pgsql.exec(
      [
        'UPDATE durable SET busy = $1',
        'WHERE human = $2 AND id = $3 AND (busy IS NULL OR busy = $1)',
        'RETURNING id'
      ],
      [owner, human.id, id]
    )
    raise Busy, "The durable ##{id} is busy or does not exist" if rows.empty?
  end

  # Unlock one durable.
  #
  # @param [Integer] id The ID of the durable to lock
  # @param [String] owner The owner of the lock
  def unlock(id, owner)
    rows = pgsql.exec(
      'UPDATE durable SET busy = NULL WHERE human = $1 AND id = $2 AND busy = $3 RETURNING id',
      [human.id, id, owner]
    )
    raise Busy, "The durable ##{id} is either not locked or locked by someone else" if rows.empty?
  end

  # Start a new durable (using the file provided) or return an already existing one.
  #
  # @param [String] jname The name of a job
  # @param [String] directory The directory of the durable
  # @param [String] file The file where to get start content
  # @return [Integer] The ID of the durable created or found
  def place(jname, directory, file)
    pgsql.transaction do |t|
      t.exec('LOCK human')
      rows = t.exec(
        'SELECT id FROM durable WHERE human = $1 AND jname = $2 AND directory = $3',
        [human.id, jname, directory]
      )
      if rows.empty?
        t.exec(
          'INSERT INTO durable (human, jname, directory, uri, size) VALUES ($1, $2, $3, $4, $5) RETURNING id',
          [human.id, jname, directory, @fbs.save(file), File.size(file)]
        ).first['id'].to_i
      else
        rows.first['id'].to_i
      end
    end
  end

  # Dowload the durable from the cloud and save into the file provided.
  #
  # @param [Integer] id The ID of the durable to lock
  # @param [String] file The file where to save it
  def load(id, file)
    uri = pgsql.exec(
      'SELECT uri FROM durable WHERE human = $1 AND id = $2',
      [human.id, id]
    ).first['uri']
    @fbs.load(uri, file)
  end

  # Put it back to cloud and delete all files from the +target+ directory.
  #
  # @param [Integer] id The ID of the durable to lock
  # @param [String] file The file where to take the content
  # @return [String] URI of the file just saved to the cloud
  def save(id, file)
    uri = @fbs.save(file)
    pgsql.exec(
      'UPDATE durable SET uri = $3, size = $4 WHERE human = $1 AND id = $2',
      [human.id, id, uri, File.size(file)]
    )
    uri
  end
end
