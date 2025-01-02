# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2025 Zerocracy
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

require 'aws-sdk-sqs'
require 'aws-sdk-core'
require 'loog'

# SQS client.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::SQS
  # Ctor.
  #
  # @param [String] key AWS authentication key (if empty, the object will NOT use AWS S3)
  # @param [String] secret AWS authentication secret
  # @param [String] region AWS region
  # @param [String] url The URL of the queue
  # @param [Loog] loog Logging facility
  def initialize(key, secret, url, region = 'us-east-1', loog: Loog::NULL)
    @key = key
    @secret = secret
    @region = region
    @url = url
    @loog = loog
  end

  # Create a new message with the given body.
  #
  # @param [Baza::Job] job The job that originates this
  # @param [String] body The body of the SQS message
  # @return [Integer] The ID of the SQS message
  def push(job, body)
    if @key.empty?
      42
    else
      jid = job.nil? ? 0 : job.id
      id = aws.send_message(
        queue_url: @url,
        message_body: body,
        message_attributes: {
          'baza' => {
            string_value: Baza::VERSION,
            data_type: 'String'
          },
          'job' => {
            string_value: jid.to_s,
            data_type: 'String'
          },
          'hops' => {
            string_value: '0',
            data_type: 'Number'
          }
        }
      ).message_id
      @loog.debug("SQS message ##{id} posted (job=#{jid}): #{body.inspect}")
      id
    end
  end

  private

  def aws
    Aws::SQS::Client.new(
      region: @region,
      credentials: Aws::Credentials.new(@key, @secret)
    )
  end
end
