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

# Garbage collector for all humans.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Gc
  attr_reader :humans

  def initialize(humans, days)
    @humans = humans
    @days = days
  end

  def pgsql
    @humans.pgsql
  end

  # Iterate jobs that may be deleted because they are too old.
  def each
    return to_enum(__method__) unless block_given?
    q =
      'SELECT f.id, token.human FROM ' \
      '(SELECT l.id, l.token, l.created, COUNT(r.name) AS total, MAX(r.created) AS recent FROM job AS l ' \
      'JOIN job AS r ON l.name = r.name ' \
      'WHERE l.expired IS NULL ' \
      'GROUP BY l.id) AS f ' \
      'JOIN token ON token.id = token ' \
      'WHERE f.total > 1 ' \
      "AND f.created < NOW() - INTERVAL '#{@days.to_i} DAYS' " \
      'AND f.recent != f.created'
    pgsql.exec(q).each do |row|
      yield @humans.get(row['human'].to_i).jobs.get(row['id'].to_i)
    end
  end
end
