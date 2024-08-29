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
require 'backtrace'
require 'elapsed'
require 'fileutils'
require_relative 'ec2'
require_relative 'shell'

# Docker image for AWS Lambda.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Image
  # Ctor.
  #
  # @param [Baza::Humans] humans The humans
  # @param [String] account AWS account ID
  # @param [String] region AWS region
  # @param [Loog] loog Logging facility
  def initialize(humans, account, region, loog: Loog::NULL)
    @humans = humans
    @account = account
    @region = region
    @loog = loog
  end

  # Package all necessary files for Docker image.
  #
  # @param [String] file Path of the .zip file to create
  # @return [String] File path of .zip
  def pack(file)
    Dir.mktmpdir do |home|
      [
        '../../Gemfile',
        '../../Gemfile.lock',
        '../../assets/lambda/entry.rb',
        '../../assets/lambda/install-pgsql.sh'
      ].each do |f|
        FileUtils.copy(File.join(__dir__, f), File.join(home, File.basename(f)))
      end
      FileUtils.mkdir_p(File.join(home, 'swarms'))
      File.write(File.join(home, 'swarms/.keep'), '')
      installs = []
      each_swarm do |swarm|
        dir = checkout(swarm)
        next if dir.nil?
        sub = "swarms/#{swarm.name}"
        target = File.join(home, sub)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.copy_entry(dir, target)
        installs << install(target, sub)
      end
      dockerfile = Liquid::Template.parse(File.read(File.join(__dir__, '../../assets/lambda/Dockerfile'))).render(
        'from' => "#{@account}.dkr.ecr.#{@region}.amazonaws.com/zerocracy/baza:basic",
        'installs' => installs.join("\n")
      )
      File.write(File.join(home, 'Dockerfile'), dockerfile)
      @loog.debug("This is the Dockerfile:\n#{dockerfile}")
      Baza::Zip.new(file, loog: @loog).pack(home)
    end
    file
  end

  # Create install commands for Docker, from this directory.
  #
  # @param [String] dir The local directory with swarm content files, e.g. "/tmp/bar/foo-contents"
  # @param [String] sub Subdirectory inside docker image, e.g. "swarms/foo"
  def install(dir, sub)
    gemfile = File.join(dir, 'Gemfile.lock')
    if File.exist?(gemfile)
      "RUN bundle install --gemfile=#{sub}/Gemfile"
    else
      ''
    end
  end

  # Checkout swarm and return the directory where it's located. Also,
  # update its SHA if necessary.
  #
  # @param [Baza::Swarm] swarm The swarm
  # @return [String] Path to location
  def checkout(swarm)
    elapsed(@loog, intro: "Checked out #{swarm.name} swarm") do
      sub = "swarms/#{swarm.name}"
      dir = File.join('/tmp', sub)
      FileUtils.mkdir_p(File.dirname(dir))
      git = ['set -ex', 'date', 'git --version']
      if File.exist?(dir)
        git += ["cd #{dir}", 'git pull']
      else
        git << "git clone -b #{swarm.branch} --depth=1 --single-branch git@github.com:#{swarm.repository}.git #{dir}"
      end
      git << 'git rev-parse HEAD'
      stdout = `(#{git.join(' && ')}) 2>&1`
      @loog.debug("Checkout log of #{swarm.name}:\n#{stdout}")
      swarm.stdout!(stdout)
      code = $CHILD_STATUS.exitstatus
      swarm.exit!(code)
      return nil unless code.zero?
      dir
    end
  end

  # Iterate all swarms that need to be deployed.
  def each_swarm
    @humans.pgsql.exec('SELECT * FROM swarm').each do |row|
      yield @humans.find_swarm(row['repository'], row['branch'])
    end
  end
end
