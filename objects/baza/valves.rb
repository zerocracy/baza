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
require_relative 'tbot'

# Valves of a human.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Valves
  attr_reader :human

  def initialize(human, tbot: Baza::Tbot::Fake.new)
    @human = human
    @tbot = tbot
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

  def each(offset: 0)
    return to_enum(__method__, offset:) unless block_given?
    pgsql.exec(
      [
        'SELECT valve.*, COUNT(job.id) AS jobs FROM valve',
        'LEFT JOIN job ON job.name = valve.name',
        'WHERE human = $1',
        'GROUP BY valve.id',
        'ORDER BY valve.created DESC',
        "OFFSET #{offset.to_i}"
      ],
      [@human.id]
    ).each do |row|
      v = {
        id: row['id'].to_i,
        created: Time.parse(row['created']),
        name: row['name'],
        badge: row['badge'],
        result: dec(row['result']),
        why: row['why'],
        jobs: row['jobs'].to_i
      }
      yield v
    end
  end

  def enter(name, badge, why)
    raise 'A block is required by the enter()' unless block_given?
    raise Baza::Urror, 'The name cannot be nil' if name.nil?
    raise Baza::Urror, 'The name cannot be empty' if name.empty?
    raise Baza::Urror, 'The name is not valid' unless name.match?(/^[a-z0-9]+$/)
    raise Baza::Urror, 'The badge cannot be nil' if badge.nil?
    raise Baza::Urror, 'The badge cannot be empty' if badge.empty?
    raise Baza::Urror, "The badge '#{badge}' is not valid" unless badge.match?(/^[a-zA-Z0-9_-]+$/)
    raise Baza::Urror, 'The reason cannot be empty' if why.empty?
    start = Time.now
    catch :stop do
      loop do
        catch :rollback do
          pgsql.transaction do |t|
            row = t.exec(
              [
                'INSERT INTO valve (human, name, badge, owner, why) ',
                'VALUES ($1, $2, $3, 1, $4) ',
                'ON CONFLICT(human, name, badge) DO UPDATE SET owner = valve.owner + 1 ',
                'RETURNING id, owner, result'
              ],
              [@human.id, name.downcase, badge, why]
            )[0]
            unless row['result'].nil?
              t.exec('ROLLBACK')
              return dec(row['result'])
            end
            unless row['owner'] == '1'
              t.exec('ROLLBACK')
              throw :rollback
            end
            human.notify(
              "🍒 A new [valve](https://www.zerocracy.com/valves) ##{row['id']}",
              "just entered for the `#{name}` job: #{why.inspect}."
            )
            t.exec('COMMIT')
            throw :stop
          end
        end
        raise "Time out while waiting for '#{badge}'" if Time.now - start > 60
      end
    end
    begin
      r = yield
      pgsql.exec(
        'UPDATE valve SET result = $1 WHERE human = $2 AND name = $3 AND badge = $4',
        [enc(r), @human.id, name.downcase, badge]
      )
      r
    rescue StandardError => e
      pgsql.exec(
        'DELETE FROM valve WHERE human = $1 AND name = $2 AND badge = $3',
        [@human.id, name.downcase, badge]
      )
      raise e
    end
  end

  def remove(id)
    pgsql.exec(
      'DELETE FROM valve WHERE id = $1 AND human = $2',
      [id, @human.id]
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
