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
require_relative 'shell'
require_relative 'image'

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
  def initialize(humans, account, key, secret, region, sgroup, subnet, image, ssh_key,
    tbot: Baza::Tbot::Fake.new, loog: Loog::NULL, type: 't2.xlarge', user: 'ubuntu', port: 22)
    @humans = humans
    @image = Baza::Image.new(humans, account, region, loog:)
    @ec2 = Baza::EC2.new(key, secret, region, sgroup, subnet, image, type:, loog:)
    @shell = Baza::Shell.new(ssh_key, user, port, loog:) unless key.empty?
    @account = account
    @secret = secret
    @region = region
    @tbot = tbot
    @loog = loog
  end

  # Deploy all swarms into AWS Lambda.
  #
  # @param [String] tag Docker tag to use
  def deploy(tag = 'latest')
    return unless dirty?
    Dir.mktmpdir do |home|
      zip = @image.pack(File.join(home, 'image.zip'))
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

  private

  # Build a new Docker image in a new EC2 server and publish it to
  # Lambda function.
  def build_and_publish(ip, zip, tag)
    @shell.connect(ip) do |ssh|
      code =
        begin
          @loog.debug("Logged into EC2 instance #{ip} as #{@user.inspect}")
          ssh.upload(zip, 'baza.zip')
          ssh.upload_file(
            'credentials',
            [
              '[default]',
              "aws_access_key_id = #{@key}",
              "aws_secret_access_key = #{@secret}"
            ].join("\n")
          )
          ssh.upload_file(
            'config',
            [
              '[default]',
              "region = #{@region}"
            ].join("\n")
          )
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
          code = ssh.exec(script)
        rescue StandardError => e
          @loog.warn(Backtrace.new(e))
          raise e
        end
      raise "Failed with ##{code}" unless code.zero?
      @loog.debug('Docker image built successfully')
      # update Lambda function to use new image
    end
  end

  # What is the current SHA of the AWS lambda function?
  #
  # @return [String] The SHA or '' if no lambda function found
  def aws_sha
    ''
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
