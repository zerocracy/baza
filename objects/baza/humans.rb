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

require_relative 'human'
require_relative 'urror'

# All humans.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Humans
  attr_reader :pgsql

  def initialize(pgsql)
    @pgsql = pgsql
  end

  def exists?(login)
    !@pgsql.exec('SELECT id FROM human WHERE github = $1', [login]).empty?
  end

  def find(login)
    rows = @pgsql.exec(
      'SELECT id FROM human WHERE github = $1',
      [login]
    )
    raise Baza::Urror, "Human @#{login} not found" if rows.empty?
    Baza::Human.new(self, rows[0]['id'].to_i)
  end

  # Make sure this human exists (create if it doesn't) and return it.
  def ensure(login)
    raise Baza::Urror, 'GitHub login is empty' if login.empty?
    raise Baza::Urror, "GitHub login too long: \"@#{login}\"" if login.length > 64
    rows = @pgsql.exec(
      'INSERT INTO human (github) VALUES ($1) ON CONFLICT DO NOTHING RETURNING id',
      [login]
    )
    return find(login) if rows.empty?
    Baza::Human.new(self, rows[0]['id'].to_i)
  end
end
