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

# A single receipt.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Receipt
  attr_reader :id

  def initialize(account, id)
    @account = account
    @id = id
  end

  def job_id
    to_json[:job_id]
  end

  def zents
    to_json[:zents]
  end

  def summary
    to_json[:summary]
  end

  def created
    to_json[:created]
  end

  private

  def to_json(*_args)
    @to_json ||=
      begin
        row = @account.pgsql.exec(
          [
            'SELECT receipt.* FROM receipt',
            'WHERE id = $1 AND human = $2'
          ],
          [@id, @account.human.id]
        ).first
        raise Baza::Urror, "There is no receipt ##{@id}" if row.nil?
        {
          id: @id,
          zents: row['zents'].to_i,
          created: Time.parse(row['created']),
          summary: row['summary'],
          job_id: row['job']&.to_i
        }
      end
  end
end
