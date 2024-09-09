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

require 'aws-sdk-core'
require 'aws-sdk-s3'
require 'backtrace'
require 'elapsed'
require 'English'
require 'iri'
require 'json'
require 'loog'
require 'typhoeus'
require 'archive/zip'

# This is needed because of this: https://github.com/aws/aws-lambda-ruby-runtime-interface-client/issues/14
require 'aws_lambda_ric'
require 'io/console'
require 'stringio'
module AwsLambdaRuntimeInterfaceClient
  class LambdaRunner
    def send_error_response(lambda_invocation, err, exit_code = nil, runtime_loop_active = true)
      error_object = err.to_lambda_response
      @lambda_server.send_error_response(
        request_id: lambda_invocation.request_id,
        error_object: error_object,
        error: err,
        xray_cause: XRayCause.new(error_object).as_json
      )
      @exit_code = exit_code unless exit_code.nil?
      @runtime_loop_active = runtime_loop_active
    end
  end
end

# Download object from AWS S3.
def get_object(key, file, loog)
  Aws::S3::Client.new.get_object(
    response_target: file,
    bucket: '{{ bucket }}',
    key:
  )
  loog.info("Loaded S3 object #{key.inspect} from bucket #{bucket.inspect}")
end

# Upload object to AWS S3.
def put_object(key, file, loog)
  File.open(file, 'rb') do |f|
    Aws::S3::Client.new.put_object(
      body: f,
      bucket: '{{ bucket }}',
      key:
    )
  end
  loog.info("Saved S3 object #{key.inspect} to bucket #{bucket.inspect}")
end

# Send message to AWS SQS queue.
def send_message(id, loog)
  Aws::SQS::Client.new.send_message(
    queue_url: "https://sqs.{{ region }}.amazonaws.com/{{ account }}/baza-shift",
    message_body: "Job ##{id} was processed by {{ name }}",
    message_attributes: {
      'swarm' => {
        string_value: '{{ swarm }}',
        data_type: 'String'
      },
      'job' => {
        string_value: id.to_s,
        data_type: 'String'
      }
    }
  )
  loog.info("Sent message to SQS about job ##{id}")
end

def report(stdout, job)
  home = Iri.new('{{ host }}')
    .append('swarms')
    .append('{{ swarm }}'.to_i)
    .append('invocation')
    .add(secret: '{{ secret }}')
  home = home.add(job: job) unless job.nil?
  ret = Typhoeus::Request.put(
    home.to_s,
    connecttimeout: 30,
    timeout: 300,
    body: stdout,
    headers: {
      'Content-Type' => 'text/plain',
      'Content-Length' => stdout.length
    }
  )
  puts "Reported to #{home}: #{ret.code}"
end

def with_zip(id, rec, loog)
  Dir.mktmpdir do |home|
    zip = File.join(home, "#{id}.zip")
    key = "{{ name }}/#{id}.zip"
    get_object(key, zip, loog)
    pack = File.join(home, id.to_s)
    Archive::Zip.extract(zip, pack)
    loog.info("Unpacked ZIP (#{File.size(zip)} bytes)")
    File.delete(zip)
    rec_file = File.join(pack, 'event.json')
    File.write(rec_file, JSON.pretty_generate(rec))
    yield pack
    FileUtils.rm_f(rec_file)
    Archive::Zip.archive(zip, File.join(pack, '/.'))
    put_object(key, zip, loog)
    send_message(id, loog)
  end
end

def one(id, pack, loog)
  cmd =
    if File.exist?('/swarm/entry.sh')
      "/bin/bash /swarm/entry.sh \"#{id}\" \"#{pack}\" 2>&1"
    elsif File.exist?('/swarm/entry.rb')
      "bundle exec ruby /swarm/entry.rb \"#{id}\" \"#{pack}\" 2>&1"
    else
      "echo 'Cannot figure out how to start the swarm, try creating \"entry.sh\" or \"entry.rb\"'"
    end
  loog.info("+ #{cmd}")
  loog.info(`SWARM_SECRET={{ secret }} SWARM_ID={{ swarm }} #{cmd}`)
  e = $CHILD_STATUS.exitstatus
  loog.warn("FAILURE (#{e})") unless e.zero?
end

def go(event:, context:)
  puts "Arrived event: #{event.to_s.inspect}"
  elapsed(intro: 'Job processing finished') do
    event['Records'].each do |rec|
      loog = Loog::Buffer.new
      begin
        job = rec['messageAttributes']['job']['stringValue'].to_i
        job = 0 if job.nil?
        if %w[baza-pop baza-shift baza-finish].include?('{{ swarm }}')
          Dir.mktmpdir do |pack|
            File.write(File.join(pack, 'event.json'), JSON.pretty_generate(rec))
            one(job, pack, loog)
          end
        else
          with_zip(job, rec, loog) do |pack|
            one(job, pack, loog)
          end
        end
      ensure
        report(loog.to_s, job)
      end
    end
  end
  'Done!'
end
