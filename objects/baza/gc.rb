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

  def initialize(humans)
    @humans = humans
  end

  def pgsql
    @humans.pgsql
  end

  # Iterate jobs that are stuck: taken too long time ago but don't have results.
  def stuck(minutes = 2 * 60)
    return to_enum(__method__, minutes) unless block_given?
    q =
      'SELECT job.id FROM job ' \
      'LEFT JOIN result ON result.job = job.id ' \
      'WHERE job.taken IS NOT NULL ' \
      'AND result.id IS NULL ' \
      'AND job.expired IS NULL ' \
      'AND result.expired IS NULL ' \
      "AND job.created < NOW() - INTERVAL '#{minutes.to_i} MINUTES'"
    pgsql.exec(q).each do |row|
      yield @humans.job_by_id(row['id'].to_i)
    end
  end

  # Iterate jobs that may be deleted because they are too old.
  def ready_to_expire(days = 90)
    return to_enum(__method__, days) unless block_given?
    q =
      'SELECT f.id FROM ' \
      '(SELECT l.id, l.token, l.created, COUNT(r.name) AS total, MAX(r.created) AS recent FROM job AS l ' \
      'JOIN job AS r ON l.name = r.name ' \
      'WHERE l.expired IS NULL ' \
      'GROUP BY l.id) AS f ' \
      'WHERE f.total > 1 ' \
      "AND f.created < NOW() - INTERVAL '#{days.to_i} DAYS' " \
      'AND f.recent != f.created'
    pgsql.exec(q).each do |row|
      yield @humans.job_by_id(row['id'].to_i)
    end
  end
end
