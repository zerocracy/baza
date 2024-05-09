# frozen_string_literal: true

# Copyright (c) 2009-2024 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require_relative 'job'

# One token.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Token
  attr_reader :id

  def initialize(tokens, id)
    @tokens = tokens
    @id = id
  end

  def pgsql
    @tokens.pgsql
  end

  def deactivate
    @tokens.pgsql.exec('UPDATE token SET active = false WHERE id = $1', [@id])
  end

  def active?
    rows = @tokens.pgsql.exec(
      'SELECT active FROM token WHERE id = $1',
      [@id]
    )
    raise Baza::Urror, "Token ##{@id} not found" if rows.empty?
    rows[0]['active'] == 't'
  end

  def start(factbase)
    rows = @tokens.pgsql.exec(
      'INSERT INTO job (token, factbase) VALUES ($1, $2) RETURNING id',
      [@id, factbase]
    )
    id = rows[0]['id'].to_i
    Baza::Job.new(self, id)
  end

  def name
    rows = @tokens.pgsql.exec(
      'SELECT name FROM token WHERE id = $1',
      [@id]
    )
    raise Baza::Urror, "Token ##{@id} not found" if rows.empty?
    rows[0]['name']
  end

  def text
    rows = @tokens.pgsql.exec(
      'SELECT text FROM token WHERE id = $1',
      [@id]
    )
    raise Baza::Urror, "Token ##{@id} not found" if rows.empty?
    rows[0]['text']
  end

  def to_json(*_args)
    {
      id: @id,
      name: name,
      text: text
    }
  end
end
