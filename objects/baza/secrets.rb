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

# Locks of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Secrets
  attr_reader :human

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def empty?
    pgsql.exec(
      'SELECT id FROM secret WHERE human = $1',
      [@human.id]
    ).empty?
  end

  def each(&block)
    pgsql.exec('SELECT * FROM secret WHERE human = $1', [@human.id]).each(&block)
  end

  def add(name, key, value)
    pgsql.exec(
      'INSERT INTO secret (human, name, key, value) VALUES ($1, $2, $3, $4)',
      [@human.id, name, key, value]
    )
  end

  def remove(name, key)
    pgsql.exec(
      'DELETE FROM secret WHERE human = $1 AND name = $2 AND key = $3',
      [@human.id, name, key]
    )
  end
end