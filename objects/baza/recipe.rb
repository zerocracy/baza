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
  # @param [Loog] loog Logging facility
  def initialize(swarm, loog: Loog::NULL)
    @swarm = swarm
    @loog = loog
  end

  # Make it a bash script.
  #
  # @return [String] Bash script to use in EC2
  def to_bash(account, region, tag, secret)
    file_of(
      'recipe.sh',
      'save_files' => [
        cat('Gemfile'),
        cat('entry.rb'),
        cat('install-pgsql.sh'),
        cat('install.sh'),
        cat('Dockerfile', 'from' => "#{account}.dkr.ecr.#{region}.amazonaws.com")
      ].join,
      'name' => @swarm.name,
      'github' => @swarm.repository,
      'branch' => @swarm.branch,
      'region' => region,
      'repository' => "#{account}.dkr.ecr.#{region}.amazonaws.com",
      'image' => "zerocracy/baza:#{tag}",
      'secret' => secret
    )
  end

  private

  def file_of(file, args = {})
    dir = File.join(__dir__, '../../assets/lambda')
    Liquid::Template.parse(File.read(File.join(dir, file))).render(args)
  end

  def cat(file, args = {})
    txt = file_of(file, args)
    m = "EOT_#{SecureRandom.hex(8)}"
    "\ncat > #{file} <<#{m}\n#{txt}\n#{m}\n"
  end
end
