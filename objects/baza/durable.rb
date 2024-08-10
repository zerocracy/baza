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

# One durable of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Durable
  attr_reader :human, :id

  # When can't lock a durable.
  class Busy < StandardError; end

  # @param [Integer] id The ID of the durable to lock
  def initialize(human, fbs, id)
    @human = human
    @fbs = fbs
    @id = id
  end

  def pgsql
    @human.pgsql
  end

  # Lock one durable.
  #
  # @param [String] owner The owner of the lock
  def lock(owner)
    rows = pgsql.exec(
      [
        'UPDATE durable SET busy = $1',
        'WHERE (busy IS NULL OR busy = $1) AND id = $3',
        "AND (human = $2 OR file LIKE '@%')",
        'RETURNING id'
      ],
      [owner, human.id, @id]
    )
    raise Busy, "The durable ##{@id} is busy or does not exist" if rows.empty?
  end

  # Unlock one durable.
  #
  # @param [String] owner The owner of the lock
  def unlock(owner)
    rows = pgsql.exec(
      [
        'UPDATE durable SET busy = NULL',
        'WHERE busy = $3 AND id = $2',
        "AND (human = $1 OR file LIKE '@%')",
        'RETURNING id'
      ],
      [human.id, @id, owner]
    )
    raise Busy, "The durable ##{@id} is either not locked or locked by someone else" if rows.empty?
  end

  # Is it locked now?
  def locked?
    pgsql.exec(
      [
        'SELECT id FROM durable',
        'WHERE busy IS NULL AND id = $2',
        "AND (human = $1 OR file LIKE '@%')"
      ],
      [human.id, @id]
    ).empty?
  end

  # Dowload the durable from the cloud and save into the file provided.
  #
  # @param [String] file The file where to save it
  def load(file)
    uri = pgsql.exec(
      [
        'SELECT uri FROM durable',
        "WHERE id = $2 AND (human = $1 OR file LIKE '@%')"
      ],
      [human.id, @id]
    ).first['uri']
    @fbs.load(uri, file)
  end

  # Put it back to cloud and delete all files from the +target+ file.
  #
  # @param [String] file The file where to take the content
  # @return [String] URI of the file just saved to the cloud
  def save(file)
    raise Baza::Urror, "The durable ##{@id} is not locked, can't save" unless locked?
    uri = @fbs.save(file)
    before = pgsql.exec(
      "SELECT uri FROM durable WHERE id = $2 AND (human = $1 OR file LIKE '@%')",
      [human.id, @id]
    ).first['uri']
    @fbs.delete(before)
    pgsql.exec(
      [
        'UPDATE durable SET uri = $3, size = $4',
        "WHERE id = $2 OR (human = $1 AND file LIKE '@%')"
      ],
      [human.id, @id, uri, File.size(file)]
    )
    uri
  end

  # Delete it here and in the cloud.
  def delete
    @fbs.delete(uri)
    pgsql.exec(
      'DELETE FROM durable WHERE human = $1 AND id = $2',
      [human.id, @id]
    )
  end

  # Get its URI.
  def uri
    to_json[:uri]
  end

  def to_json(*_args)
    @to_json ||=
      begin
        row = pgsql.exec(
          [
            'SELECT * FROM durable',
            "WHERE id = $1 AND human = $2 OR (human = $1 AND file LIKE '@%')"
          ],
          [@id, @human.id]
        ).first
        raise Baza::Urror, "There is no durable ##{@id}" if row.nil?
        {
          id: @id,
          jname: row['jname'].downcase,
          created: Time.parse(row['created']),
          uri: row['uri'],
          file: row['file']
        }
      end
  end
end
