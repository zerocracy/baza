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
require 'elapsed'
require 'fileutils'
require 'digest/sha1'
require 'aws-sdk-ec2'
require 'aws-sdk-core'
require 'net/ssh'
require 'net/scp'
require 'openssl'

# Function in AWS Lambda.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Lambda
  # Ctor.
  #
  # @param [String] key AWS authentication key (if empty, the object will NOT use AWS S3)
  # @param [String] secret AWS authentication secret
  # @param [String] region AWS region
  # @param [String] ssh SSH private key
  # @param [Loog] loog Logging facility
  # @param [Baza:Tbot] tbot Telegram bot
  def initialize(humans, key, secret, region, sgroup, subnet, image, ssh,
    tbot: Baza::Tbot::Fake.new, loog: Loog::NULL, user: 'ubuntu', port: 22)
    @humans = humans
    @key = key
    @secret = secret
    @region = region
    @sgroup = sgroup
    @subnet = subnet
    @image = image
    ssh = ssh.gsub(/\n +/, "\n")
    OpenSSL::PKey.read(ssh) unless key.empty? # sanity check
    @ssh = ssh
    @tbot = tbot
    @loog = loog
    @user = user
    @port = port
  end

  # Deploy all swarms into AWS Lambda.
  def deploy
    return unless dirty?
    Dir.mktmpdir do |home|
      zip = File.join(home, 'image.zip')
      pack(zip)
      sha = Digest::SHA1.hexdigest(File.binread(zip))
      break if aws_sha == sha
      build_and_publish(zip)
      done!
    end
  end

  private

  # Build a new Docker image in a new EC2 server and publish it to
  # Lambda function.
  def build_and_publish(zip)
    id = run_instance
    begin
      ip = host_of(warm(id))
      @loog.debug("The IP of #{id} is #{ip}")
      Net::SSH.start(ip, @user, port: @port, keys: [], key_data: [@ssh], keys_only: true) do |ssh|
        @loog.debug("Logged into EC2 instance #{ip} as '#{@user}'")
        ssh.scp.upload(zip, '/tmp/baza.zip')
        @loog.debug("ZIP (#{File.size(zip)} bytes) uploaded to EC2 instance #{id}")
        script = [
          'set -ex',
          'cd /tmp',
          'rm -rf baza',
          'unzip baza.zip -d baza',
          'docker build baza -t baza'
        ].join(' && ')
        ssh.exec!(script) do |_, stream, data|
          @loog.debug(data) if stream == :stdout
        end
        @loog.debug("Docker image built successfully")
        # 'docker push' to ECR
        # update Lambda function to use new image
      end
    ensure
      terminate(id)
    end
  end

  def warm(id)
    elapsed(@loog, intro: 'Warmed up EC2 instance') do
      start = Time.now
      loop do
        status = status_of(id)
        @loog.debug("Status of #{id} is #{status.inspect}")
        break if status == 'ok'
        raise "Looks like #{id} will never be OK" if Time.now - start > 60 * 10
        sleep 15
      end
      id
    end
  end

  # Terminate one EC2 instance.
  def terminate(id)
    elapsed(@loog, intro: "Terminated EC2 instance #{id}") do
      ec2.terminate_instances(instance_ids: [id])
    end
  end

  # Get IP of the running EC2 instance.
  def host_of(id)
    elapsed(@loog, intro: "Found IP address of #{id}") do
      ec2.describe_instances(instance_ids: [id])
        .reservations[0]
        .instances[0]
        .public_ip_address
    end
  end

  def status_of(id)
    elapsed(@loog, intro: "Detected status of #{id}") do
      ec2.describe_instance_status(instance_ids: [id], include_all_instances: true)
        .instance_statuses[0]
        .instance_status
        .status
    end
  end

  def run_instance
    elapsed(@loog, intro: 'Started new EC2 instance') do
      ec2.run_instances(
        image_id: @image,
        instance_type: 't2.large',
        max_count: 1,
        min_count: 1,
        security_group_ids: [@sgroup],
        subnet_id: @subnet,
        tag_specifications: [
          {
            resource_type: 'instance',
            tags: [
              {
                key: 'Name',
                value: 'baza-deploy',
              },
            ],
          },
        ],
      ).instances[0].instance_id
    end
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
  def pack(file)
    Dir.mktmpdir do |home|
      [
        '../../Gemfile',
        '../../Gemfile.lock',
        '../../assets/lambda/entry.rb'
      ].each do |f|
        FileUtils.copy(File.join(__dir__, f), File.join(home, File.basename(f)))
      end
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
        'installs' => installs.join("\n")
      )
      File.write(File.join(home, 'Dockerfile'), dockerfile)
      @loog.debug("This is the Dockerfile:\n#{dockerfile}")
      Baza::Zip.new(file, loog: @loog).pack(home)
    end
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
      @loog.debug(stdout)
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

  def ec2
    Aws::EC2::Client.new(
      region: @region,
      credentials: Aws::Credentials.new(@key, @secret),
    )
  end
end
