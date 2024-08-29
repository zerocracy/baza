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
require 'digest/sha1'
require 'aws-sdk-core'
require 'net/ssh'
require 'net/scp'
require 'openssl'
require_relative 'ec2'

# Function in AWS Lambda.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Lambda
  # Ctor.
  #
  # @param [String] account AWS account ID
  # @param [String] key AWS authentication key (if empty, the object will NOT use AWS S3)
  # @param [String] secret AWS authentication secret
  # @param [String] region AWS region
  # @param [String] ssh SSH private key
  # @param [Loog] loog Logging facility
  # @param [Baza:Tbot] tbot Telegram bot
  def initialize(humans, account, key, secret, region, sgroup, subnet, image, ssh,
    tbot: Baza::Tbot::Fake.new, loog: Loog::NULL, type: 't2.xlarge', user: 'ubuntu', port: 22)
    @humans = humans
    @ec2 = Baza::EC2.new(key, secret, region, sgroup, subnet, image, type:, loog:)
    @account = account
    @key = key
    @secret = secret
    @region = region
    ssh = ssh.gsub(/\n +/, "\n")
    OpenSSL::PKey.read(ssh) unless key.empty? # sanity check
    @ssh = ssh
    @tbot = tbot
    @loog = loog
    @user = user
    @port = port
  end

  # Deploy all swarms into AWS Lambda.
  #
  # @param [String] tag Docker tag to use
  def deploy(tag = 'latest')
    return unless dirty?
    Dir.mktmpdir do |home|
      zip = pack(File.join(home, 'image.zip'))
      sha = Digest::SHA1.hexdigest(File.binread(zip))
      break if aws_sha == sha
      instance_id = @ec2.run_instance
      begin
        build_and_publish(@ec2.host_of(@ec2.warm(instance_id)), zip, tag)
      ensure
        @ec2.terminate(instance_id)
      end
      done!
    end
  end

  # private

  # Build a new Docker image in a new EC2 server and publish it to
  # Lambda function.
  def build_and_publish(ip, zip, tag)
    terminal(ip) do |ssh|
      code =
        begin
          @loog.debug("Logged into EC2 instance #{ip} as #{@user.inspect}")
          upload(ssh, zip, 'baza.zip')
          upload_file(
            ssh, 'credentials',
            [
              '[default]',
              "aws_access_key_id = #{@key}",
              "aws_secret_access_key = #{@secret}"
            ].join("\n")
          )
          upload_file(
            ssh, 'config',
            [
              '[default]',
              "region = #{@region}"
            ].join("\n")
          )
          code = push(ssh, tag)
        rescue StandardError => e
          @loog.warn(Backtrace.new(e))
          raise e
        end
      raise "Failed with ##{code}" unless code.zero?
      @loog.debug('Docker image built successfully')
      # update Lambda function to use new image
    end
  end

  def upload_file(ssh, path, content)
    Tempfile.open do |f|
      File.write(f.path, content)
      upload(ssh, f.path, path)
    end
  end

  # Build a new Docker image in a new EC2 server and publish it to
  # Lambda function.
  def upload(ssh, file, path)
    ssh.scp.upload!(file, path)
    @loog.debug("#{File.basename(file)} (#{File.size(file)} bytes) uploaded to #{path}")
  end

  # @return [Integer] Exit code
  def push(ssh, tag)
    script = [
      'set -ex',
      'PATH=$PATH:$(pwd)',
      'mkdir .aws',
      'mv credentials .aws',
      'mv config .aws',
      "aws ecr get-login-password --region #{@region} | docker login --username AWS --password-stdin #{@account}.dkr.ecr.#{@region}.amazonaws.com",
      'mkdir --p baza',
      'rm -rf baza/*',
      'unzip -qq baza.zip -d baza',
      'docker build baza -t baza',
      "docker tag baza #{@account}.dkr.ecr.#{@region}.amazonaws.com/zerocracy/baza:#{tag}",
      "docker push #{@account}.dkr.ecr.#{@region}.amazonaws.com/zerocracy/baza:#{tag}"
    ].join(' && ')
    script = "( #{script} ) 2>&1"
    stdout = ''
    code = nil
    ssh.open_channel do |channel|
      channel.exec(script) do |ch, success|
        ch.on_data do |_, data|
          stdout += data
          lines = stdout.split(/\n/, -1)
          lines[..-2].each do |ln|
            @loog.debug(ln.strip)
          end
          stdout = lines[-1]
        end
        ch.on_request('exit-status') do |_, data|
          code = data.read_long
        end
      end
    end
    ssh.loop
    code
  end

  def terminal(ip)
    Net::SSH.start(ip, @user, port: @port, keys: [], key_data: [@ssh], keys_only: true, timeout: 60_000) do |ssh|
      yield ssh
    end
  rescue Net::SSH::Disconnect => e
    @loog.warn("There is a temporary error, will retry: #{e.message}")
    retry
  end

  # What is the current SHA of the AWS lambda function?
  #
  # @return [String] The SHA or '' if no lambda function found
  def aws_sha
    ''
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

  # Returns TRUE if at least one swarm is "dirty" and because of that
  # the entire pack must be re-deployed.
  def dirty?
    !@humans.pgsql.exec('SELECT id FROM swarm WHERE dirty = TRUE').empty?
  end

  # Mark all swarms as "not dirty any more".
  def done!
    @humans.pgsql.exec('UPDATE swarm SET dirty = FALSE')
  end
end
