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

# Valves of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Valves
  attr_reader :human

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def empty?
    pgsql.exec(
      'SELECT id FROM valve WHERE human = $1',
      [@human.id]
    ).empty?
  end

  def each
    return to_enum(__method__) unless block_given?
    pgsql.exec('SELECT * FROM valve WHERE human = $1', [@human.id]).each do |row|
      v = {
        name: row['name'],
        badge: row['badge'],
        result: dec(row['result'])
      }
      yield v
    end
  end

  def enter(name, badge)
    raise 'A block is required by the enter()' unless block_given?
    raise Baza::Urror, 'The name cannot be empty' if name.empty?
    raise Baza::Urror, 'The name is not valid' unless name.match?(/^[a-z0-9]+$/)
    raise Baza::Urror, 'The badge cannot be empty' if badge.empty?
    raise Baza::Urror, "The badge '#{badge}' is not valid" unless badge.match?(/^[a-zA-Z0-9_-]+$/)
    start = Time.now
    catch :stop do
      loop do
        catch :rollback do
          pgsql.transaction do |t|
            row = t.exec(
              [
                'INSERT INTO valve (human, name, badge, owner) ',
                'VALUES ($1, $2, $3, 1) ',
                'ON CONFLICT(human, name, badge) DO UPDATE SET owner = valve.owner + 1 ',
                'RETURNING owner, result'
              ],
              [@human.id, name, badge]
            )[0]
            return dec(row['result']) unless row['result'].nil?
            throw :rollback unless row['owner'] == '1'
            throw :stop
          end
        end
        raise "Time out while waiting for '#{badge}'" if Time.now - start > 60
      end
    end
    r = yield
    pgsql.exec(
      'UPDATE valve SET result = $1 WHERE human = $2 AND name = $3 AND badge = $4',
      [enc(r), @human.id, name, badge]
    )
    r
  end

  def remove(name, badge)
    pgsql.exec(
      'DELETE FROM valve WHERE human = $1 AND name = $2 AND badge = $3',
      [@human.id, name, badge]
    )
  end

  private

  def enc(obj)
    Base64.encode64(Marshal.dump(obj))
  end

  def dec(base64)
    # rubocop:disable Security/MarshalLoad
    Marshal.load(Base64.decode64(base64))
    # rubocop:enable Security/MarshalLoad
  end
end
