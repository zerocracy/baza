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
        job: row['job']&.to_i,
        result: row['result'].nil? ? nil : dec(row['result']),
        why: row['why'],
        jobs: row['jobs'].to_i
      }
      yield v
    end
  end

  # Create a new valve (guaranteed to be unique).
  #
  # A block must be provided, which will calculate the value of the valve:
  #
  #  valves.enter('foo', 'email-sent', 'sent only once!', nil) do
  #    467747897 # this is the ID of the email sent, to be calculated only once
  #  end
  #
  # @param [String] name Job name
  # @param [String] badge Unique name of the badge
  # @param [String] why The reason for creating this valve (any text)
  # @param [nil|Integer] job NIL if not related to any running job, or job ID
  # @return [nil] Nothing
  def enter(name, badge, why, job)
    raise 'A block is required by the enter()' unless block_given?
    raise Baza::Urror, 'The name cannot be nil' if name.nil?
    raise Baza::Urror, 'The name cannot be empty' if name.empty?
    raise Baza::Urror, 'The name is not valid' unless name.match?(/^[a-z0-9]+$/)
    raise Baza::Urror, 'The badge cannot be nil' if badge.nil?
    raise Baza::Urror, 'The badge cannot be empty' if badge.empty?
    raise Baza::Urror, "The badge '#{badge}' is not valid" unless badge.match?(/^[a-zA-Z0-9_-]+$/)
    raise Baza::Urror, 'The reason cannot be nil' if why.nil?
    raise Baza::Urror, 'The reason cannot be empty' if why.empty?
    raise Baza::Urror, 'The job may either be NIL or Integer' unless job.nil? || job.is_a?(Integer)
    start = Time.now
    catch :stop do
      loop do
        catch :rollback do
          pgsql.transaction do |t|
            row = t.exec(
              [
                'INSERT INTO valve (human, name, badge, owner, why, job) ',
                'VALUES ($1, $2, $3, 1, $4, $5) ',
                'ON CONFLICT(human, name, badge) DO UPDATE SET owner = valve.owner + 1 ',
                'RETURNING id, owner, result'
              ],
              [@human.id, name.downcase, badge, why, job]
            )[0]
            unless row['result'].nil?
              t.exec('ROLLBACK')
              return dec(row['result'])
            end
            unless row['owner'] == '1'
              t.exec('ROLLBACK')
              throw :rollback
            end
            t.exec('COMMIT')
            throw :stop
          end
        end
        raise "Time out while waiting for '#{badge}' (probably another job is holding it)" if Time.now - start > 60
      end
    end
    begin
      r = yield
      row = pgsql.exec(
        'UPDATE valve SET result = $1 WHERE human = $2 AND name = $3 AND badge = $4 RETURNING id',
        [enc(r), @human.id, name.downcase, badge]
      ).first
      human.notify(
        "🍒 A new [valve](//valves/#{row['id']}) ##{row['id']}",
        "just entered for the `#{name}` job",
        job.nil? ? '' : "([##{job}](//jobs/#{job}))",
        ": #{escape(why.inspect)}.",
        "The result is #{show(r)}."
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
    rows = pgsql.exec(
      'DELETE FROM valve WHERE id = $1 AND human = $2 RETURNING id',
      [id, @human.id]
    )
    raise Baza::Urror, "The valve ##{id} cannot be removed" if rows.empty?
  end

  def reset(id, result)
    rows = pgsql.exec(
      'UPDATE valve SET result = $1 WHERE id = $2 AND human = $3 RETURNING id',
      [enc(result), id, @human.id]
    )
    raise Baza::Urror, "The valve ##{id} cannot be reset" if rows.empty?
  end

  def get(id)
    raise 'Valve ID must be an integer' unless id.is_a?(Integer)
    require_relative 'valve'
    Baza::Valve.new(self, id)
  end

  private

  # Make it suitable for Telegram (where they expect Markdown).
  def escape(txt)
    txt
      .gsub('[', '\[')
      .gsub(']', '\]')
      .gsub(/@([a-zA-Z0-9-]+)/, '[@\1](https://github.com/\1)')
      .gsub(%r{([\.a-zA-Z0-9_\-]+/[\.a-zA-Z0-9_\-]+)#([0-9]+)}) do |s|
        "[#{s}](https://github.com/#{Regexp.last_match[1]}/issues/#{Regexp.last_match[2]})"
      end
  end

  def enc(obj)
    return obj if obj.nil?
    Base64.encode64(Marshal.dump(obj))
  end

  def dec(base64)
    # rubocop:disable Security/MarshalLoad
    Marshal.load(Base64.decode64(base64))
    # rubocop:enable Security/MarshalLoad
  end

  def show(res)
    if res.is_a?(Integer) || res.is_a?(Float)
      "`#{res}`"
    elsif res.is_a?(String)
      if res.start_with?('http')
        "[link](#{res})"
      else
        "\"#{escape(res)}\""
      end
    else
      "instance of `#{res.class}`"
    end
  end
end
