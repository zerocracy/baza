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

# Locks of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Locks
  attr_reader :human

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def locked?(name)
    !pgsql.exec(
      'SELECT lock.id FROM lock WHERE human = $1 AND name = $2',
      [@human.id, name]
    ).empty?
  end

  def lock(name)
    pgsql.exec(
      'INSERT INTO lock (human, name) VALUES ($1, $2) RETURNING id',
      [@human.id, name]
    )[0]['id'].to_i
  end

  def unlock(name)
    pgsql.exec(
      'DELETE FROM lock WHERE human = $1 AND name = $2',
      [@human.id, name]
    )
  end
end
