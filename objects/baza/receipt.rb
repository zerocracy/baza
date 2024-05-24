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

# Account of a human.
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
    id = @account.pgsql.exec(
      'SELECT job FROM receipt WHERE id = $1',
      [@id]
    )[0]['job']
    return nil if id.nil?
    id.to_i
  end

  def zents
    @account.pgsql.exec(
      'SELECT zents FROM receipt WHERE id = $1',
      [@id]
    )[0]['zents'].to_i
  end

  def summary
    @account.pgsql.exec(
      'SELECT summary FROM receipt WHERE id = $1',
      [@id]
    )[0]['summary']
  end

  def created
    time = @account.pgsql.exec(
      'SELECT created FROM receipt WHERE id = $1',
      [@id]
    )[0]['created']
    Time.parse(time)
  end
end
