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

require 'English'
require 'liquid'
require 'csv'
require 'backtrace'
require 'elapsed'
require 'fileutils'
require_relative 'ec2'
require_relative 'shell'

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
  def to_bash
    Dir.mktmpdir do |home|
      [
        'Gemfile',
        'entry.rb',
        'install-pgsql.sh',
        'install-swarms.sh'
      ].each { |f| copy_to(home, f) }
      copy_to(
        home,
        'release.sh',
        'region' => @region,
        'repository' => "#{@account}.dkr.ecr.#{@region}.amazonaws.com",
        'image' => "zerocracy/baza:#{@tag}"
      )
      copy_to(
        home,
        'Dockerfile',
        'from' => @from
      )
      File.write(
        File.join(home, 'swarms.csv'),
        CSV.generate do |csv|
          swarms.each { |s| csv << [s.name, s.repository, s.branch] }
        end
      )
      FileUtils.mkdir_p(File.join(home, 'swarms'))
      Baza::Zip.new(file, loog: @loog).pack(home)
    end
    file
  end

  private

  def copy_to(home, file, args = {})
    dir = File.join(__dir__, '../../assets/lambda')
    target = File.join(home, file)
    File.write(
      target,
      Liquid::Template.parse(File.read(File.join(dir, file))).render(args)
    )
    @loog.debug("This is the #{file}:\n#{File.read(target)}")
  end

  # Iterate all swarms that need to be deployed.
  def swarms
    @humans.pgsql.exec('SELECT * FROM swarm').each.to_a.map do |row|
      @humans.find_swarm(row['repository'], row['branch'])
    end
  end
end
