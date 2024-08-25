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

# A swarm of a human.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Swarm
  attr_reader :swarms, :id

  def initialize(swarms, id, tbot: Baza::Tbot::Fake.new)
    @swarms = swarms
    @id = id
    @tbot = tbot
  end

  # Change DIRTY status of the swarm.
  #
  # @param [Bool] yes TRUE if it has to become dirty
  def dirty!(yes)
    swarms.pgsql.exec(
      'UPDATE swarm SET dirty = $1 WHERE id = $2 AND human = $3',
      [yes, @id, swarms.human.id]
    )
  end

  # Change exit code of the swarm.
  #
  # @param [Integer] code The exit code of the deployment attempt
  def exit!(code)
    swarms.pgsql.exec(
      'UPDATE swarm SET exit = $1 WHERE id = $2 AND human = $3',
      [code, @id, swarms.human.id]
    )
  end

  # Change STDOUT of the latest deployment of the swarm.
  #
  # @param [String] log The stdout of the deployment attempt of the swarm
  def stdout!(log)
    swarms.pgsql.exec(
      'UPDATE swarm SET stdout = $1 WHERE id = $2 AND human = $3',
      [log, @id, @swarms.human.id]
    )
  end

  def remove
    swarms.pgsql.exec(
      'DELETE FROM swarm WHERE id = $1 AND human = $2',
      [@id, @swarms.human.id]
    )
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

  # Get its stdout.
  def stdout
    to_json[:stdout]
  end

  # Get its exit code.
  def exit
    to_json[:exit]
  end

  # Get its dirty status.
  def dirty
    to_json[:dirty]
  end

  private

  def to_json(*_args)
    @to_json ||=
      begin
        row = swarms.pgsql.exec(
          'SELECT * FROM swarm WHERE id = $1 AND human = $2',
          [@id, @swarms.human.id]
        ).first
        raise Baza::Urror, "There is no swarm ##{@id}" if row.nil?
        {
          id: @id,
          name: row['name'],
          repository: row['repository'],
          branch: row['branch'],
          dirty: row['dirty'] == 't',
          stdout: row['stdout'],
          exit: row['exit'].to_i,
          created: Time.parse(row['created'])
        }
      end
  end
end
