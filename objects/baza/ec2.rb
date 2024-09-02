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
  #
  # @param [Loog] loog Logging facility
  def initialize(key, secret, region, sgroup, subnet, image,
    loog: Loog::NULL, type: 't2.xlarge')
    raise Baza::Urror, "AWS key is wrong: #{key.inspect}" unless key.match?(/^(AKIA|FAKE)[A-Z0-9]{16}$/)
    @key = key
    raise Baza::Urror, "AWS secret is wrong: #{secret.inspect}" unless secret.match?(%r{^[A-Za-z0-9/]{40}$})
    @secret = secret
    @region = region
    @sgroup = sgroup
    @subnet = subnet
    @image = image
    @type = type
    @loog = loog
  end

  def run_instance(name, data)
    elapsed(@loog, intro: "Started new #{@type.inspect} EC2 instance") do
      aws.run_instances(
        image_id: @image,
        instance_type: @type,
        max_count: 1,
        min_count: 1,
        user_data: data,
        security_group_ids: [@sgroup],
        subnet_id: @subnet,
        instance_initiated_shutdown_behavior: 'terminate',
        tag_specifications: [
          {
            resource_type: 'instance',
            tags: [
              {
                key: 'Name',
                value: name
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
