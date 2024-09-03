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

# All releases of a swarm.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Releases
  attr_reader :swarm

  def initialize(swarm, tbot: Baza::Tbot::Fake.new)
    @swarm = swarm
    @tbot = tbot
  end

  def pgsql
    @swarm.pgsql
  end

  def get(id)
    raise 'Release ID must be an integer' unless id.is_a?(Integer)
    require_relative 'release'
    Baza::Release.new(self, id, tbot: @tbot)
  end

  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    rows = @swarm.pgsql.exec(
      [
        'SELECT * FROM release',
        'WHERE swarm = $1',
        'ORDER BY created DESC',
        "OFFSET #{offset.to_i}"
      ],
      [@swarm.id]
    )
    rows.each do |row|
      r = {
        id: row['id'].to_i,
        head: row['head'],
        secret: row['secret'],
        exit: row['exit']&.to_i,
        tail: row['tail'],
        msec: row['msec']&.to_i,
        created: Time.parse(row['created'])
      }
      yield r
    end
  end

  # Start a new release to the swarm.
  #
  # @param [String] instance AWS EC2 instance ID
  # @param [String] secret A secret
  # @return [Integer] The ID of the added release
  def start(tail, secret)
    raise Baza::Urror, 'The "tail" cannot be NIL' if tail.nil?
    raise Baza::Urror, 'The "secret" cannot be empty' if secret.nil?
    get(
      @swarm.pgsql.exec(
        'INSERT INTO release (swarm, tail, secret) VALUES ($1, $2, $3) RETURNING id',
        [@swarm.id, tail, secret]
      )[0]['id'].to_i
    )
  end
end
