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

require_relative 'urror'

# Human being.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Human
  attr_reader :id, :humans

  def initialize(humans, id)
    @humans = humans
    raise 'Human ID must be an integer' unless id.is_a?(Integer)
    @id = id
  end

  def pgsql
    @humans.pgsql
  end

  def tokens
    require_relative 'tokens'
    Baza::Tokens.new(self)
  end

  def jobs
    require_relative 'jobs'
    Baza::Jobs.new(self)
  end

  def results
    require_relative 'results'
    Baza::Results.new(self)
  end

  def account
    require_relative 'account'
    Baza::Account.new(self)
  end

  def github
    rows = @humans.pgsql.exec(
      'SELECT github FROM human WHERE id = $1',
      [@id]
    )
    raise Baza::Urror, "Human ##{@id} not found" if rows.empty?
    rows[0]['github']
  end

  # An admin.
  module Admin
    def admin?
      github == 'yegor256' || ENV['RACK_ENV'] == 'test'
    end
  end
end
