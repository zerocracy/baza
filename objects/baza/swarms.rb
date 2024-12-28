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
require 'securerandom'

# Swarms of a human.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Swarms
  attr_reader :human

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def get(id)
    raise 'Swarm ID must be an integer' unless id.is_a?(Integer)
    require_relative 'swarm'
    Baza::Swarm.new(self, id)
  end

  def empty?
    pgsql.exec(
      'SELECT id FROM swarm WHERE human = $1',
      [@human.id]
    ).empty?
  end

  # Iterate over all swarms.
  # @param [Integer] offset The offset to start with
  # @yield [Baza::Swarm] A swarm
  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    rows = pgsql.exec(
      [
        'SELECT s.*, COUNT(release.id) AS releases_count,',
        '(SELECT version FROM release',
        '  WHERE swarm = s.id AND version IS NOT NULL',
        '  ORDER BY release.id DESC LIMIT 1) AS version,',
        '(SELECT exit FROM release WHERE swarm = s.id ORDER BY release.id DESC LIMIT 1) AS exit,',
        '(SELECT created FROM invocation WHERE swarm = s.id ORDER BY invocation.id DESC LIMIT 1) AS invoked',
        'FROM swarm AS s',
        'LEFT JOIN release ON release.swarm = s.id',
        'WHERE human = $1',
        'GROUP BY s.id',
        'ORDER BY s.name',
        "OFFSET #{offset.to_i}"
      ],
      [@human.id]
    )
    rows.each do |row|
      yield Veil.new(
        get(row['id'].to_i),
        id: row['id'].to_i,
        name: row['name'],
        exit: row['exit']&.to_i,
        releases_count: row['releases_count'].to_i,
        version: row['version'],
        enabled: row['enabled'] == 't',
        repository: row['repository'],
        directory: row['directory'],
        branch: row['branch'],
        secret: row['secret'],
        head: row['head'],
        invoked: row['invoked'].nil? ? nil : Time.parse(row['invoked']),
        created: Time.parse(row['created'])
      )
    end
  end

  # Add new swarm and return its ID.
  #
  # @param [String] name Name of the swarm
  # @param [String] repo Name of repository
  # @param [String] branch Name of branch
  # @param [String] directory Name of directory in the Git branch (use '/' for root)
  # @return [Baza::Swarm] The added swarm
  def add(name, repo, branch, directory)
    raise Baza::Urror, 'The "name" cannot be empty' if name.empty?
    raise Baza::Urror, "The name #{name.inspect} is not valid" unless name.match?(/^[a-z0-9-]+$/)
    raise Baza::Urror, 'The "repo" cannot be empty' if repo.empty?
    raise Baza::Urror, 'The "directory" cannot be empty' if directory.empty?
    if %w[pop shift alterations finish] && !@human.extend(Baza::Human::Roles).admin?
      raise Baza::Urror, "The name #{name.inspect} can be used only by admin"
    end
    unless repo.match?(%r{^[a-zA-Z][a-zA-Z0-9\-.]*/[a-zA-Z][a-z0-9\-.]*$})
      raise Baza::Urror, "The repo #{repo.inspect} is not valid"
    end
    secret = SecureRandom.uuid
    get(
      pgsql.exec(
        [
          'INSERT INTO swarm',
          '(human, name, repository, branch, directory, secret)',
          'VALUES ($1, $2, $3, $4, $5, $6) RETURNING id'
        ],
        [@human.id, name.downcase, repo, branch, directory, secret]
      )[0]['id'].to_i
    )
  end
end
