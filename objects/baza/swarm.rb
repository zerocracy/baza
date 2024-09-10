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

require 'tago'

# A swarm of a human.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Swarm
  attr_reader :swarms, :id

  def initialize(swarms, id)
    @swarms = swarms
    @id = id
  end

  def pgsql
    @swarms.pgsql
  end

  # Change head SHA of the swarm.
  #
  # @param [String] sha The hash of the Git head
  def head!(sha)
    swarms.pgsql.exec(
      'UPDATE swarm SET head = $1 WHERE id = $2 AND human = $3',
      [sha, @id, swarms.human.id]
    )
    @to_json = nil
  end

  # Either enable it or disable.
  #
  # @param [Boolean] yes TRUE if it must be enabled
  def enable!(yes)
    swarms.pgsql.exec(
      'UPDATE swarm SET enabled = $3 WHERE id = $1 AND human = $2',
      [@id, @swarms.human.id, yes]
    )
    @to_json = nil
  end

  # Get its name.
  def name
    to_json[:name]
  end

  # Get its repo.
  def repository
    to_json[:repository]
  end

  # Get its branch.
  def branch
    to_json[:branch]
  end

  # Get its directory.
  def directory
    to_json[:directory]
  end

  # Get its secret.
  def secret
    to_json[:secret]
  end

  # Get its head SHA.
  def head
    to_json[:head]
  end

  # Get its enabled status.
  def enabled?
    to_json[:enabled]
  end

  # Get its time of creation.
  def created
    to_json[:created]
  end

  # Get the time of the recent invocation.
  def invoked
    to_json[:invoked]
  end

  # Get the count of releases.
  def releases_count
    to_json[:releases_count]
  end

  # Get its releases.
  def releases
    require_relative 'releases'
    Baza::Releases.new(self)
  end

  # Get its invocations.
  def invocations
    require_relative 'invocations'
    Baza::Invocations.new(self)
  end

  # Explain why we are not releasing now or return NIL if ready to release.
  #
  # @param [Integer] hours How many hours to wait between retries on failure
  # @param [Integer] minutes How many minutes to wait between successful releases
  # @return [String] Explanation of why we don't release now (or NIL if we can release)
  def why_not(hours: 24, minutes: 60)
    return "The swarm ##{@id} is disabled." unless enabled?
    if head == '0' * 40
      return 'The swarm has just been created, we are waiting for the first webhook to arrive (did you configure it?).'
    end
    last = releases.each.to_a.first
    return nil if last.nil?
    return "The release ##{last[:id]} is not yet finished, we're waiting for it." if last[:exit].nil?
    if last[:head] == head
      return \
        "The SHA of the head of the release ##{last[:id]} (#{last[:head][0..6].downcase}) " \
        'equals to the SHA of the head of the swarm, no need to release.'
    end
    return nil if last[:head] == 'F' * 40
    delay = hours * 60 * 60
    if !last[:exit].zero? && Time.now - delay < last[:created]
      return \
        "The latest release ##{last[:id]} failed just #{last[:created].ago} ago, " \
        "we must wait #{(last[:created] + delay).ago} " \
        'and then make another release attempt.'
    end
    pause = minutes * 60
    if Time.now - pause < last[:created]
      return \
        "The latest successfull release ##{last[:id]} just happened #{last[:created].ago} ago, " \
        "we'll wait #{(last[:created] + pause).ago} " \
        'and only then will release again.'
    end
    nil
  end

  private

  def to_json(*_args)
    @to_json ||=
      begin
        row = swarms.pgsql.exec(
          [
            'SELECT s.*, COUNT(release.id) AS releases_count,',
            '(SELECT exit FROM release WHERE swarm = s.id ORDER BY release.id DESC LIMIT 1) AS exit,',
            '(SELECT created FROM invocation WHERE swarm = s.id ORDER BY invocation.id DESC LIMIT 1) AS invoked',
            'FROM swarm AS s',
            'LEFT JOIN release ON release.swarm = s.id',
            'WHERE s.id = $1 AND s.human = $2',
            'GROUP BY s.id'
          ],
          [@id, @swarms.human.id]
        ).first
        raise Baza::Urror, "There is no swarm ##{@id}" if row.nil?
        {
          id: @id,
          name: row['name'],
          exit: row['exit']&.to_i,
          enabled: row['enabled'] == 't',
          releases_count: row['releases_count'].to_i,
          repository: row['repository'],
          branch: row['branch'],
          directory: row['directory'],
          secret: row['secret'],
          head: row['head'],
          invoked: row['invoked'].nil? ? nil : Time.parse(row['invoked']),
          created: Time.parse(row['created'])
        }
      end
  end
end
