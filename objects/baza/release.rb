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
  attr_reader :releases

  def initialize(releases, id, tbot: Baza::Tbot::Fake.new)
    @releases = releases
    @id = id
    @tbot = tbot
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
      [@id, head, tail, code, msec, @swarm.id]
    )
  end
end
