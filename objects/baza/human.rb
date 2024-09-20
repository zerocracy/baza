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

require_relative 'urror'
require_relative 'tbot'

# Human being.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Human
  attr_reader :id, :humans

  def initialize(humans, id, tbot: Baza::Tbot::Fake.new)
    @humans = humans
    raise 'Human ID must be an integer' unless id.is_a?(Integer)
    @id = id
    @tbot = tbot
  end

  # How much zents to charge per millisecond of server time.
  # @return [Float] Number of zents per millisecond
  def price
    0.16
  end

  def pgsql
    @humans.pgsql
  end

  def tokens
    require_relative 'tokens'
    Baza::Tokens.new(self)
  end

  def jobs
    require_relative 'jobs'
    Baza::Jobs.new(self)
  end

  def notifications
    require_relative 'notifications'
    Baza::Notifications.new(self)
  end

  def locks
    require_relative 'locks'
    Baza::Locks.new(self)
  end

  def secrets
    require_relative 'secrets'
    Baza::Secrets.new(self)
  end

  def durables(fbs)
    require_relative 'durables'
    Baza::Durables.new(self, fbs)
  end

  def alterations
    require_relative 'alterations'
    Baza::Alterations.new(self)
  end

  def swarms
    require_relative 'swarms'
    Baza::Swarms.new(self)
  end

  def valves
    require_relative 'valves'
    Baza::Valves.new(self, tbot: @tbot)
  end

  def results
    require_relative 'results'
    Baza::Results.new(self)
  end

  def account
    require_relative 'account'
    Baza::Account.new(self)
  end

  def invocation_by_id(id)
    row = pgsql.exec(
      [
        'SELECT invocation.*, job.name,',
        'swarm.name AS swarm, swarm.id AS swarm_id,',
        'human.github AS human',
        'FROM invocation',
        'JOIN job ON job.id = invocation.job',
        'JOIN token ON token.id = job.token',
        'JOIN human ON token.human = human.id',
        'JOIN swarm ON swarm.id = invocation.swarm',
        'WHERE invocation.id = $1 AND (token.human = $2',
        extend(Baza::Human::Roles).admin? ? 'OR TRUE)' : ')'
      ],
      [id, @id]
    ).first
    raise Baza::Urror, "The invocation ##{id} not found" if row.nil?
    {
      id: row['id'].to_i,
      code: row['code'].to_i,
      job: row['job']&.to_i,
      name: row['name'],
      human: row['human'],
      swarm: row['swarm'],
      swarm_id: row['swarm_id'].to_i,
      stdout: row['stdout'],
      created: Time.parse(row['created'])
    }
  end

  def telegram?
    !@humans.pgsql.exec(
      'SELECT id FROM telechat WHERE human = $1',
      [@id]
    ).empty?
  end

  def github
    rows = @humans.pgsql.exec(
      'SELECT github FROM human WHERE id = $1',
      [@id]
    )
    raise Baza::Urror, "Human ##{@id} not found, can't find his GitHub name" if rows.empty?
    rows[0]['github']
  end

  # Notify this user via telegram.
  def notify(*lines)
    @tbot.notify(self, *lines)
  end

  # Roles of a human.
  module Roles
    def admin?
      github == 'yegor256' || ENV['RACK_ENV'] == 'test'
    end

    def tester?
      github == '!tester' || ENV['RACK_ENV'] == 'test'
    end
  end
end
