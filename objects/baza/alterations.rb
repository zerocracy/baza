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

require 'liquid'

# Alterations of a human.
#
# Every alteration is a Ruby script that is supposed to be executed
# as a judge on a Factbase of the job.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Alterations
  attr_reader :human

  def initialize(human)
    @human = human
  end

  def pgsql
    @human.pgsql
  end

  def empty?
    pgsql.exec(
      'SELECT id FROM alteration WHERE human = $1',
      [@human.id]
    ).empty?
  end

  def each(pending: false)
    return to_enum(__method__, pending:) unless block_given?
    rows = pgsql.exec(
      [
        'SELECT alteration.*, b.id AS applied, COUNT(a.id) AS jobs FROM alteration',
        'LEFT JOIN job AS a ON a.name = alteration.name',
        'LEFT JOIN job AS b ON b.id = alteration.job',
        'WHERE alteration.human = $1',
        (pending ? 'AND job IS NULL' : ''),
        'GROUP BY alteration.id, b.id',
        'ORDER BY alteration.created DESC'
      ],
      [@human.id]
    )
    rows.each do |row|
      s = {
        id: row['id'].to_i,
        name: row['name'],
        script: row['script'],
        created: Time.parse(row['created']),
        jobs: row['jobs'].to_i,
        applied: row['applied']&.to_i
      }
      yield s
    end
  end

  def add(name, template, params)
    raise Baza::Urror, 'The name cannot be empty' if name.empty?
    raise Baza::Urror, 'The name is not valid' unless name.match?(/^[a-z0-9]+$/)
    script =
      if template == 'ruby'
        raise Baza::Urror, 'You cannot do this' unless @human.extend(Baza::Human::Roles).admin?
        params[:script]
      else
        script(template, params)
      end
    pgsql.exec(
      'INSERT INTO alteration (human, name, script) VALUES ($1, $2, $3) RETURNING id',
      [@human.id, name.downcase, script]
    )[0]['id'].to_i
  end

  def complete(id, job)
    pgsql.exec(
      'UPDATE alteration SET job = $1 WHERE id = $2 AND human = $3',
      [job, id, @human.id]
    )
  end

  def remove(id)
    pgsql.exec(
      'DELETE FROM alteration WHERE id = $1 AND human = $2',
      [id, @human.id]
    )
  end

  private

  def script(template, params)
    raise Baza::Urror, 'Wrong template name' unless template =~ /^[a-z0-9-]+$/
    file = File.join(__dir__, "../../assets/alterations/#{template}.liquid")
    Liquid::Template.parse(File.read(file)).render(
      params
        .transform_keys do |k|
          raise Baza::Urror, "Wrong param name '#{k}'" unless k =~ /^[a-z0-9-]+$/
          k.to_s
        end
        .transform_values { |v| v.gsub(/['"\u0000]/, ' ') }
    )
  end
end
