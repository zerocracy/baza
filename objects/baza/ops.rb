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

require 'securerandom'
require_relative 'recipe'

# Operations with swarms and their releases.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Ops
  # Ctor.
  #
  # @param [Baza::Swarm] swarm The swarm
  # @param [Loog] loog Logging facility
  def initialize(ec2, account, id_rsa, loog: Loog::NULL)
    @ec2 = ec2
    @account = account
    @id_rsa = id_rsa
    @loog = loog
  end

  # Release this swarm.
  #
  # @param [Baza::Swarm] swarm The swarm
  def release(swarm)
    secret = SecureRandom.uuid
    instance = @ec2.run_instance(
      "baza/#{swarm.name}",
      Baza::Recipe.new(swarm, @id_rsa.gsub(/\n +/, "\n")).to_bash(
        :release, @account, @ec2.region, secret
      )
    )
    swarm.releases.start(greeting('releasing', instance), secret)
  end

  # Destroy this swarm.
  #
  # @param [Baza::Swarm] swarm The swarm
  def destroy(swarm)
    secret = SecureRandom.uuid
    instance = @ec2.run_instance(
      "baza/#{swarm.name}",
      Baza::Recipe.new(swarm, @id_rsa.gsub(/\n +/, "\n")).to_bash(
        :destroy, @account, @ec2.region, secret
      )
    )
    swarm.releases.start(greeting('destroying', instance), secret)
  end

  private

  def greeting(action, instance)
    [
      "We are #{action} in EC2 #{@ec2.type.inspect} instance #{instance.inspect}...",
      'Run this command in the console, to get the logs from AWS EC2:',
      "aws ec2 get-console-output --instance-id #{instance} --output text"
    ].join("\n")
  end
end
