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

require_relative '../objects/baza/ec2'
require_relative '../objects/baza/swarm'
require_relative '../objects/baza/recipe'

cfg = settings.config['lambda']
type = 't2.xlarge'
ec2 = Baza::EC2.new(
  cfg['key'],
  cfg['secret'],
  cfg['region'],
  cfg['sgroup'],
  cfg['subnet'],
  cfg['image'],
  type:,
  loog: settings.loog
)
settings.pgsql.exec('SELECT * FROM swarm').each do |row|
  swarm = Baza::Swarm.new(settings.humans.get(row['human'].to_i).swarms, row['id'].to_i, tbot: settings.tbot)
  next unless swarm.why_not.nil?
  secret = SecureRandom.uuid
  instance = ec2.run_instance(
    "baza/#{swarm.name}",
    Baza::Recipe.new(swarm, cfg['id_rsa']).to_bash(cfg['account'], cfg['region'], secret)
  )
  swarm.releases.start("Started AWS EC2 #{type.inspect} instance #{instance.inspect}...", secret)
end
