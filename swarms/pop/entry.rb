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

require 'archive/zip'
require 'aws-sdk-core'
require 'aws-sdk-s3'
require 'aws-sdk-sqs'
require 'baza-rb'
require 'fileutils'
require 'loog'

loog = Loog::VERBOSE

baza = BazaRb.new('www.zerocracy.com', 443, ENV.fetch('SWARM_SECRET', ''), loog:)
elapsed(loog) do
  Dir.mktmpdir do |home|
    owner = 'baza-pop-swarm'
    zip = File.join(home, 'pack.zip')
    FileUtils.touch(zip)
    unless baza.pop(owner, zip)
      loog.info('No jobs available on the server')
      break
    end
    Archive::Zip.extract(zip, home)
    loog.info("Unpacked ZIP (#{File.size(zip)} bytes)")
    File.delete(zip)
    meta = JSON.parse(File.read(File.join(home, 'job.json')))
    id = meta['job']
    loog.info("Job ##{id} arrived")
    key = "#{id}.fb"
    bucket = 'swarms--use1-az4--x-s3'
    File.open(File.join(home, 'input.fb'), 'rb') do |f|
      Aws::S3::Client.new.put_object(body: f, bucket:, key:)
    end
    loog.info("Saved S3 object #{key.inspect} to bucket #{bucket.inspect}")
    msg = Aws::SQS::Client.new.send_message(
      queue_url: 'https://sqs.us-east-1.amazonaws.com/019644334823/baza-shift',
      message_body: "Job ##{id} needs processing",
      message_attributes: {
        'job' => {
          string_value: id.to_s,
          data_type: 'String'
        }
      }
    ).message_id
    loog.info("SQS message ##{msg} posted")
  end
end
