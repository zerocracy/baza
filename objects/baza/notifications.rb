# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2025 Zerocracy
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

# Notifications of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Notifications
  attr_reader :human

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  # Post a single notification to the human. The notification will be
  # ignored if another notification with the same +badge+ (no matter
  # what was the text) has already been posted.
  #
  # @param [String] badge A unique short text, as a marker
  # @param [Array<String>] lines List of lines to post, to be joined with a space
  # @param [Integer] lifetime How many seconds to wait until a similar post is possible (NIL means forever)
  # @return [Boolean] TRUE if human was notified, FALSE otherwise
  def post(badge, *lines, lifetime: nil)
    return false unless pgsql.exec(
      [
        'SELECT id FROM notification',
        'WHERE badge = $1 AND human = $2',
        lifetime.nil? ? '' : "AND created > NOW() - INTERVAL '#{lifetime.to_i} SECONDS'"
      ],
      [badge, @human.id]
    ).empty?
    pgsql.exec(
      [
        'INSERT INTO notification (human, badge, text) VALUES ($1, $2, $3)',
        'ON CONFLICT (human, badge) DO UPDATE SET created = NOW()'
      ],
      [@human.id, badge, lines.join(' ')]
    )
    @human.notify(lines)
    true
  end
end
