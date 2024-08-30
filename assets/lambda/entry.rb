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

# {
#   "Records": [
#     {
#       "messageId": "19dd0b57-b21e-4ac1-bd88-01bbb068cb78",
#       "receiptHandle": "MessageReceiptHandle",
#       "body": "Hello from SQS!",
#       "attributes": {
#         "ApproximateReceiveCount": "1",
#         "SentTimestamp": "1523232000000",
#         "SenderId": "123456789012",
#         "ApproximateFirstReceiveTimestamp": "1523232000001"
#       },
#       "messageAttributes": {},
#       "md5OfBody": "{{{md5_of_body}}}",
#       "eventSource": "aws:sqs",
#       "eventSourceARN": "arn:aws:sqs:us-east-1:123456789012:MyQueue",
#       "awsRegion": "us-east-1"
#     }
#   ]
# }

require 'baza-rb'
require 'loog'
require 'aws-sdk-s3'
require 'aws-sdk-core'

def go(json, loog: Loog::VERBOSE, bucket: 'baza.zerocracy.com')
  loog.debug("Service gem version: #{Aws::S3::GEM_VERSION}")
  loog.debug("Core version: #{Aws::CORE_GEM_VERSION}")
  loog.debug("Input: #{json.inspect}")
  json['Records'].each do |rec|
    if rec['messageAttributes']['object'].nil?
      # get ZIP from baza /take
      # put it to S3
      # post a message to SQS
    else
      # download S3 object
      # unzip it
      # read list of passed swarms from JSON
      # remove them from the unzipped archive
      # if no swarms left
        # delete object in S3
        # push zip to baza /finish
      # else
        # remove all swarms but the first one
        # run "judges"
        # zip a package
        # put it to S3 (replacing the previous one)
        # post a message to SQS
    end
  end
  Aws::S3::Client.new
  'Done!'
end
