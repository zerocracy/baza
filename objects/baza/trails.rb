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

require 'json'

# Trails of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Trails
  def initialize(pgsql)
    @pgsql = pgsql
  end

  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    @pgsql.exec(
      [
        'SELECT trail.* FROM trail',
        'ORDER BY trail.created DESC',
        "OFFSET #{offset.to_i}"
      ]
    ).each do |row|
      v = {
        id: row['id'].to_i,
        created: Time.parse(row['created']),
        judge: row['judge'],
        name: row['name'],
        json: JSON.parse(row['json']),
        job: row['job']&.to_i
      }
      yield v
    end
  end

  # Add new trail.
  # @param [Baza::Job] job The job this trail is related to
  # @param [String] judge The name of the judge
  # @param [String] name The name of the trail left, e.g. "1.json"
  # @param [Hash] json The JSON object after parsing
  def add(job, judge, name, json)
    raise Baza::Urror, 'The JSON must be a hash' unless json.is_a?(Hash)
    @pgsql.exec(
      'INSERT INTO trail (job, judge, name, json) VALUES ($1, $2, $3, $4) RETURNING id',
      [job.id, judge.downcase, name.downcase, JSON.pretty_generate(json)]
    ).first['id'].to_i
  end
end
