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
require 'fileutils'

# Bash script for EC2 instance to build Docker image and publish to Lambda.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Recipe
  # Ctor.
  #
  # @param [Baza::Swarm] swarm The swarm
  # @param [String] id_rsa RSA private key
  # @param [Loog] loog Logging facility
  def initialize(swarm, id_rsa, loog: Loog::NULL)
    @swarm = swarm
    @id_rsa = id_rsa
    @loog = loog
  end

  # Make it a bash script.
  #
  # @return [String] Bash script to use in EC2
  def to_bash(account, region, secret)
    file_of(
      'recipe.sh',
      'save_files' => [
        cat('id_rsa', @id_rsa),
        cat_of('Gemfile'),
        cat_of('entry.rb'),
        cat_of('install-pgsql.sh'),
        cat_of('install.sh'),
        cat_of(
          'Dockerfile',
          'from' => secret.empty? \
            ? 'public.ecr.aws/lambda/ruby:3.2'
            : "#{account}.dkr.ecr.#{region}.amazonaws.com/zerocracy/baza:basic"
        )
      ].join,
      'name' => @swarm.name,
      'github' => @swarm.repository,
      'branch' => @swarm.branch,
      'region' => region,
      'repository' => "#{account}.dkr.ecr.#{region}.amazonaws.com",
      'image' => "zerocracy/swarms:#{@swarm.name}",
      'secret' => secret
    )
  end

  private

  def file_of(file, args = {})
    dir = File.join(__dir__, '../../assets/lambda')
    Liquid::Template.parse(File.read(File.join(dir, file))).render(args)
  end

  def cat_of(file, args = {})
    txt = file_of(file, args)
    cat(file, txt)
  end

  def cat(file, txt)
    m = "EOT_#{SecureRandom.hex(8)}"
    "\ncat > #{file} <<#{m}\n#{txt}\n#{m}\n"
  end
end
