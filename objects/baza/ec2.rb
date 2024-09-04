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
require 'base64'

# AWS EC2.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::EC2
  attr_reader :type, :region

  # Ctor.
  #
  # @param [String] key AWS authentication key (if empty, the object will NOT use AWS S3)
  # @param [String] secret AWS authentication secret
  # @param [String] region AWS region
  #
  # @param [Loog] loog Logging facility
  def initialize(key, secret, region, sgroup, subnet, image,
    loog: Loog::NULL, type: 't2.xlarge')
    raise Baza::Urror, 'AWS key is nil' if key.nil?
    raise Baza::Urror, "AWS key is wrong: #{key.inspect}" unless key.match?(/^(AKIA|FAKE|STUB)[A-Z0-9]{16}$/)
    @key = key
    raise Baza::Urror, 'AWS secret is nil' if secret.nil?
    raise Baza::Urror, "AWS secret is wrong: #{secret.inspect}" unless secret.match?(%r{^[A-Za-z0-9/]{40}$})
    @secret = secret
    raise Baza::Urror, 'AWS region is nil' if region.nil?
    @region = region
    raise Baza::Urror, 'AWS security group is nil' if sgroup.nil?
    @sgroup = sgroup
    raise Baza::Urror, 'AWS subnet is nil' if subnet.nil?
    @subnet = subnet
    raise Baza::Urror, 'AWS image is nil' if image.nil?
    @image = image
    raise Baza::Urror, 'AWS image type is nil' if type.nil?
    @type = type
    @loog = loog
  end

  def run_instance(tag, data)
    raise Baza::Urror, 'AWS image tag is nil' if tag.nil?
    raise Baza::Urror, 'AWS image user_data is nil' if data.nil?
    return 'i-42424242' if @key.start_with?('FAKE')
    elapsed(@loog, intro: "Started new #{@type.inspect} EC2 instance") do
      aws.run_instances(
        image_id: @image,
        instance_type: @type,
        max_count: 1,
        min_count: 1,
        user_data: Base64.encode64(data),
        security_group_ids: [@sgroup],
        subnet_id: @subnet,
        instance_initiated_shutdown_behavior: 'terminate',
        iam_instance_profile: {
          name: 'baza-release'
        },
        tag_specifications: [
          {
            resource_type: 'instance',
            tags: [
              {
                key: 'Name',
                value: tag
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
      credentials: Aws::Credentials.new(@key, @secret)
    )
  end
end
