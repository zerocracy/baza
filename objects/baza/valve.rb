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

require 'base64'

# One valve.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Valve
  attr_reader :id, :valves

  def initialize(valves, id)
    @valves = valves
    raise 'Valve ID must be an integer' unless id.is_a?(Integer)
    @id = id
  end

  def pgsql
    @valves.pgsql
  end

  def name
    to_json[:name]
  end

  def created
    to_json[:created]
  end

  def badge
    to_json[:badge]
  end

  def why
    to_json[:why]
  end

  def result
    to_json[:result]
  end

  def job
    to_json[:job]
  end

  def to_json(*_args)
    @to_json ||=
      begin
        row = pgsql.exec(
          [
            'SELECT valve.*',
            'FROM valve',
            'WHERE valve.id = $1 AND valve.human = $2'
          ],
          [@id, @valves.human.id]
        ).first
        raise Baza::Urror, "There is no valve ##{@id}" if row.nil?
        {
          id: @id,
          name: row['name'].downcase,
          created: Time.parse(row['created']),
          badge: row['badge'],
          why: row['why'],
          result: row['result'].nil? ? nil : dec(row['result']),
          job: row['job'].nil? ? nil : @valves.human.jobs.get(row['job'].to_i)
        }
      end
  end

  private

  def dec(base64)
    # rubocop:disable Security/MarshalLoad
    Marshal.load(Base64.decode64(base64))
    # rubocop:enable Security/MarshalLoad
  end
end
