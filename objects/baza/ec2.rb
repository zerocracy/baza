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

require 'aws-sdk-ec2'
require 'aws-sdk-core'

# AWS EC2.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::EC2
  # Ctor.
  #
  # @param [String] key AWS authentication key (if empty, the object will NOT use AWS S3)
  # @param [String] secret AWS authentication secret
  # @param [String] region AWS region
  # @param [Loog] loog Logging facility
  def initialize(key, secret, region, sgroup, subnet, image,
    loog: Loog::NULL, type: 't2.xlarge')
    @key = key
    @secret = secret
    @region = region
    @sgroup = sgroup
    @subnet = subnet
    @image = image
    @type = type
    @loog = loog
  end

  def warm(id)
    elapsed(@loog, intro: 'Warmed up EC2 instance') do
      start = Time.now
      attempt = 0
      loop do
        status = status_of(id)
        attempt += 1
        @loog.debug("Status of #{id} is #{status.inspect}, attempt ##{attempt}")
        break if status == 'ok'
        raise "Looks like #{id} will never be OK" if Time.now - start > 60 * 10
        sleep 30
      end
      id
    end
  end

  # Terminate one EC2 instance.
  def terminate(id)
    elapsed(@loog, intro: "Terminated EC2 instance #{id}") do
      aws.terminate_instances(instance_ids: [id])
    end
  end

  # Get IP of the running EC2 instance.
  def host_of(id)
    elapsed(@loog, intro: "Found IP address of #{id}") do
      aws.describe_instances(instance_ids: [id])
        .reservations[0]
        .instances[0]
        .public_ip_address
    end
  end

  def status_of(id)
    elapsed(@loog, intro: "Detected status of #{id}") do
      aws.describe_instance_status(instance_ids: [id], include_all_instances: true)
        .instance_statuses[0]
        .instance_status
        .status
    end
  end

  def run_instance
    elapsed(@loog, intro: "Started new #{@type.inspect} EC2 instance") do
      aws.run_instances(
        image_id: @image,
        instance_type: @type,
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
                value: 'baza-deploy'
              }
            ]
          }
        ]
      ).instances[0].instance_id
    end
  end

  def aws
    Aws::EC2::Client.new(
      region: @region,
      credentials: Aws::Credentials.new(@key, @secret),
    )
  end
end
