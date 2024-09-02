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

# A single release of a swarm.
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

  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    rows = pgsql.exec(
      [
        'SELECT * FROM release',
        'WHERE swarm = $1 and human = $1',
        "OFFSET #{offset.to_i}"
      ],
      [@swarm, @swarm.swarms.human.id]
    )
    rows.each do |row|
      r = {
        id: row['id'].to_i,
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
  def start(instance, secret)
    raise Baza::Urror, 'The "instance" cannot be NIL' if instance.nil?
    raise Baza::Urror, 'The "secret" cannot be empty' if secret.nil?
    get(
      pgsql.exec(
        'INSERT INTO release (swarm, instance, secret) VALUES ($1, $2, $3) RETURNING id',
        [@swarm.id, instance, secret]
      )[0]['id'].to_i
    )
  end

  # Finishe a release to the swarm.
  #
  # @param [Integer] id The ID of release
  # @param [String] head SHA of the Git head just released
  # @param [String] tail STDOUT tail
  # @param [String] code Exit code
  # @param [String] msec How many msec it took to build this one
  # @return [Integer] The ID of the added release
  def finish!(id, head, tail, code, msec)
    raise Baza::Urror, 'The "head" cannot be NIL' if head.nil?
    raise Baza::Urror, 'The "head" cannot be empty' if head.empty?
    raise Baza::Urror, 'The "code" must be Integer' unless code.is_a?(Integer)
    raise Baza::Urror, 'The "msec" must be Integer' unless msec.is_a?(Integer)
    get(
      pgsql.exec(
        'INSERT INTO release (swarm, head, tail, exit, msec) VALUES ($1, $2, $3, $4, $5) RETURNING id',
        [@swarm.id, head, tail, code, msec]
      )[0]['id'].to_i
    )
  end
end
