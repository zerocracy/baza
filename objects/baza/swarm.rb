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

  # Change SHA of the swarm.
  #
  # @param [String] sha The SHA of the head of the swarm
  def update(sha)
    swarms.pgsql.exec(
      'UPDATE swarm SET sha = $1 WHERE id = $2 AND human = $3',
      [sha, @id, swarms.human.id]
    )
  end

  def remove
    swarms.pgsql.exec(
      'DELETE FROM swarm WHERE id = $1 AND human = $2',
      [@id, @swarms.human.id]
    )
  end
end
