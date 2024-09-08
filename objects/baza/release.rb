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
class Baza::Release
  attr_reader :releases, :id

  def initialize(releases, id)
    @releases = releases
    @id = id
  end

  # Change head SHA of the relewase.
  #
  # @param [String] sha The hash of the Git head
  def head!(sha)
    @releases.pgsql.exec(
      'UPDATE release SET head = $1 WHERE id = $2',
      [sha, @id]
    )
    @to_json = nil
  end

  # Finish the release to the swarm.
  #
  # @param [String] head SHA of the Git head just released
  # @param [String] tail STDOUT tail
  # @param [String] code Exit code
  # @param [String] msec How many msec it took to build this one
  # @return [Integer] The ID of the added release
  def finish!(head, tail, code, msec)
    raise Baza::Urror, 'The "head" cannot be NIL' if head.nil?
    raise Baza::Urror, 'The "head" cannot be empty' if head.empty?
    raise Baza::Urror, 'The "code" must be Integer' unless code.is_a?(Integer)
    raise Baza::Urror, 'The "msec" must be Integer' unless msec.is_a?(Integer)
    @releases.pgsql.exec(
      'UPDATE release SET head = $2, tail = $3, exit = $4, msec = $5 WHERE id = $1 AND swarm = $6',
      [@id, head, tail, code, msec, @releases.swarm.id]
    )
    s = @releases.swarm
    human = s.swarms.human
    cost = (human.price * msec * 16).to_i
    human.account.top_up(
      -cost,
      "Swarm release ##{@id} (#{s.repository})",
      message: ''
    )
    human.notify(
      code.zero? ? '🫐' : '⚠️',
      "The release ##{@id} of the swarm ##{s.id} (\"`#{s.name}`\")",
      code.zero? ?
        "successfully published [#{head[0..6].downcase}](https://github.com/#{s.repository}/commit/#{head.downcase})" :
        'failed',
      "after #{format('%.2f', msec.to_f / (60 * 1000))} minutes of work,",
      "the log is [here](//swarms/#{s.id}/releases) (#{tail.split("\n").count} lines).",
      head == s.head || !code.zero? ? '' : [
        'Pay attention, the head of the swarm ',
        "[#{s.head[0..6].downcase}](https://github.com/#{s.repository}/commit/#{s.head.downcase}) is different ",
        'from what the release has published — this situation will trigger a new release soon.'
      ].join,
      "We [charged](//account) #{format('%0.2f', cost.to_f / (1000 * 100))} for this."
    )
  end

  # Get its head SHA.
  def head
    to_json[:head]
  end

  # Get its tail.
  def tail
    to_json[:tail]
  end

  # Get its exit code.
  def exit
    to_json[:exit]
  end

  # Get its msec.
  def msec
    to_json[:msec]
  end

  private

  def to_json(*_args)
    @to_json ||=
      begin
        row = @releases.pgsql.exec(
          'SELECT * FROM release WHERE id = $1',
          [@id]
        ).first
        raise Baza::Urror, "There is no release ##{@id}" if row.nil?
        {
          id: @id,
          head: row['head'],
          tail: row['tail'],
          exit: row['exit']&.to_i,
          msec: row['msec']&.to_i,
          created: Time.parse(row['created'])
        }
      end
  end
end
