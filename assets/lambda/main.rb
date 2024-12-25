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
require 'backtrace'
require 'elapsed'
require 'English'
require 'fileutils'
require 'iri'
require 'json'
require 'loog'
require 'loog/tee'
require 'qbash'
require 'timeout'
require 'typhoeus'

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
#
# @param [String] key The key in the bucket
# @param [String] file The path of the file to upload
# @param [Loog] loog The logging facility
def get_object(key, file, loog)
  bucket = '{{ bucket }}'
  Aws::S3::Client.new(region: '{{ region }}').get_object(
    response_target: file,
    bucket:,
    key:
  )
  loog.info("Loaded S3 object #{key.inspect} (#{File.size(file)} bytes) from bucket #{bucket.inspect}")
end

# Upload object to AWS S3.
#
# @param [String] key The key in the bucket
# @param [String] file The path of the file to upload
# @param [Loog] loog The logging facility
def put_object(key, file, loog)
  bucket = '{{ bucket }}'
  File.open(file, 'rb') do |f|
    Aws::S3::Client.new(region: '{{ region }}').put_object(
      body: f,
      bucket:,
      key:
    )
  end
  loog.info("Saved S3 object #{key.inspect} (#{File.size(file)} bytes) to bucket #{bucket.inspect}")
end

# Send message to AWS SQS queue "shift", to enable further processing.
#
# @param [Integer] id The ID of the job just processed
# @param [Array<String>] more List of swarm names to be processed later
# @param [Integer] hops How many hops have already been made
# @param [Hash] rec JSON event from the SQS message
# @param [Loog] loog The logging facility
def send_message(id, more, hops, rec, loog)
  attrs = {
    'shift_message' => {
      string_value: rec['messageId'],
      data_type: 'String'
    },
    'previous' => {
      string_value: '{{ name }}',
      data_type: 'String'
    },
    'job' => {
      string_value: id.to_s,
      data_type: 'String'
    },
    'hops' => {
      string_value: hops.to_s,
      data_type: 'Number'
    }
  }
  unless more.empty?
    attrs['more'] = {
      string_value: more.join(' '),
      data_type: 'String'
    }
  end
  queue = 'baza-shift'
  msg = Aws::SQS::Client.new(region: '{{ region }}').send_message(
    queue_url: "https://sqs.{{ region }}.amazonaws.com/{{ account }}/#{queue}",
    message_body: "Job ##{id} was processed by {{ name }} (swarm no.{{ swarm }})",
    message_attributes: attrs
  ).message_id
  loog.info("Swarm {{ name }} sent SQS message #{msg} about job ##{id} to #{queue} (more=#{more})")
end

# Send a report to baza about this particular invocation.
#
# @param [String] stdout Full log of the swarm
# @param [Integer] code Exit code (zero if success, something else otherwise)
# @param [Integer] job The ID of the job just processed (or NIL)
def report(stdout, code, job)
  home = Iri.new('{{ host }}')
    .append('swarms')
    .append('{{ swarm }}'.to_i)
    .append('invocation')
    .add(secret: '{{ secret }}')
    .add(code: code)
    .add(version: '{{ version }}')
  home = home.add(job: job) unless job.nil?
  ret = Typhoeus::Request.put(
    home.to_s,
    connecttimeout: 30,
    timeout: 300,
    body: stdout,
    headers: {
      'User-Agent' => '{{ name }} {{ version }}',
      'Content-Type' => 'text/plain',
      'Content-Length' => stdout.bytesize
    }
  )
  puts "Reported to #{home.to_uri.host}:#{home.to_uri.port}, received HTTP ##{ret.code}"
end

# Execute one swarm, collecting trails.
#
# @param [String] pack The directory with the unpacked ZIP
# @param [String] sub The subdir where to store trails
# @param [Loog] loog The logging facility
def with_trails(pack, sub, loog)
  jfile = File.join(pack, 'job.json')
  before = JSON.parse(File.read(jfile))
  json = before.dup
  Dir.mktmpdir do |dir|
    json['options'] = {} if json['options'].nil?
    json['options']['TRAILS_DIR'] = dir
    File.write(jfile, JSON.pretty_generate(json))
    yield pack
  ensure
    FileUtils.cp_r(dir, File.join(File.join(pack, sub), 'trails'))
    File.write(jfile, JSON.pretty_generate(before))
  end
end

# Run one swarm for a particular job, where a ZIP archvie from S3 must be processed.
#
# @param [Integer] id The ID of the job to process
# @param [Hash] rec JSON event from the SQS message
# @param [Integer] hops How many hops have already been made
# @param [Loog] loog The logging facility
# @return [Integer] Exit code (zero means success)
def with_zip(id, rec, hops, loog, &)
  Dir.mktmpdir do |home|
    zip = File.join(home, "#{id}.zip")
    key = "{{ name }}/#{id}.zip"
    begin
      get_object(key, zip, loog)
    rescue Aws::S3::Errors::NoSuchKey => e
      loog.warn("Skipping because can't find ZIP in S3: #{e.message}")
      return 0
    end
    pack = File.join(home, id.to_s)
    Archive::Zip.extract(zip, pack)
    loog.info("Unpacked ZIP (#{File.size(zip)} bytes, #{Dir[File.join(pack, '**')].count} files)")
    File.delete(zip)
    json = JSON.parse(File.read(File.join(pack, 'job.json')))
    loog.info("Job ##{json['id']} is coming from @#{json['human']}")
    rec_file = File.join(pack, 'event.json')
    File.write(rec_file, JSON.pretty_generate(rec))
    start = Time.now
    before = Dir[File.join(pack, 'swarm-*')].count
    sub = "swarm-#{format('%03d', before + 1)}-{{ swarm }}-{{ name }}"
    dir = File.join(pack, sub)
    FileUtils.mkdir_p(dir)
    stdout, code = with_trails(pack, sub, loog, &)
    FileUtils.rm_f(rec_file)
    File.write(File.join(dir, 'exit.txt'), code.to_s)
    File.write(File.join(dir, 'msec.txt'), (Time.now - start) * 1000)
    File.binwrite(File.join(dir, 'stdout.txt'), stdout)
    unless code.zero?
      loog.warn(stdout)
      loog.warn("FAILURE (#{code})")
    end
    Archive::Zip.archive(zip, File.join(pack, '/.'))
    loog.info("Packed ZIP (#{File.size(zip)} bytes, #{Dir[File.join(pack, '**')].count} files)")
    put_object(key, zip, loog)
    more = rec['messageAttributes']['more']
    if more.nil?
      more = []
    else
      more = more['stringValue'].split(' ') - ['{{ name }}']
    end
    send_message(id, more, hops, rec, loog)
    code
  end
end

# Run one swarm for a particular job.
#
# @param [Integer] id The ID of the job to process
# @param [String] pack Directory name where the ZIP is unpacked
# @param [Hash] rec JSON record arrived
# @param [Loog] loog The logging facility
# @return [Array<String, Integer>] Stdout + exit code (zero means success)
def one(id, pack, rec, loog)
  Timeout.timeout(500) do
    qbash(
      if File.exist?('/swarm/entry.sh')
        "/bin/bash /swarm/entry.sh \"#{id}\" \"#{pack}\" 2>&1"
      elsif File.exist?('/swarm/entry.rb')
        "bundle exec ruby /swarm/entry.rb \"#{id}\" \"#{pack}\" 2>&1"
      else
        "echo 'Cannot figure out how to start the swarm, try creating \"entry.sh\" or \"entry.rb\"'"
      end,
      both: true,
      log: loog,
      env: {
        'MESSAGE_ID' => rec['messageId'],
        'SWARM_SECRET' => '{{ secret }}',
        'SWARM_ID' => '{{ swarm }}',
        'SWARM_NAME' => '{{ name }}'
      },
      accept: nil
    )
  rescue Timeout::Error => e
    [Backtrace.new(e).to_s, 1]
  end
end

# Pretty print JSON event from SQS.
#
# @param [Hash] rec The JSON
# @return String Multi-line print
def pretty(rec)
  lines = [
    "MessageId: #{rec['messageId']}",
    "Body: #{rec['body']}"
  ]
  lines << "SenderId: #{rec['attributes']['SenderId'].split(':')[1]}" if rec['attributes']
  lines += rec['messageAttributes'].map { |a, h| "#{a}: \"#{h['stringValue']}\"" }
  lines.map { |ln| "  #{ln}" }.join("\n")
end

# This is the entry point called by aws_lambda_ric when a new SQS message arrives.
#
# More about the context: https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html
#
# @param [Hash] event The JSON event
# @param [LambdaContext] context I don't know what this is for
def go(event:, context:)
  loog = ENV['RACK_ENV'] == 'test' ? Loog::VERBOSE : Loog::REGULAR
  loog = Loog::NULL if event['quiet']
  loog.debug("Arrived package: #{event}")
  elapsed(loog, intro: 'Job processing finished', level: Logger::INFO) do
    event['Records']&.each do |rec|
      buf = Loog::Buffer.new
      lg = Loog::Tee.new(loog, buf)
      lg.info('Version: {{ version }}')
      lg.info("Time: #{Time.now.utc.iso8601}")
      lg.debug("Env vars: #{ENV.keys.join(', ')}")
      lg.debug("Incoming SQS event:\n#{pretty(rec)}")
      job = 0
      code = 1
      begin
        elapsed(lg, level: Logger::INFO) do
          job = rec['messageAttributes']['job']['stringValue'].to_i
          hops = rec['messageAttributes']['hops']['stringValue'].to_i
          if job.zero?
            lg.debug("A new event arrived, not related to any job (hops=#{hops})")
          else
            lg.debug("A new event arrived, about job ##{job} (hops=#{hops})")
          end
          if ['baza-pop', 'baza-shift', 'baza-finish'].include?('{{ name }}')
            lg.debug("Starting to process '{{ name }}' (system swarm)")
            Dir.mktmpdir do |pack|
              File.write(File.join(pack, 'event.json'), JSON.pretty_generate(rec))
              _, code = one(job, pack, rec, lg)
            end
          else
            lg.debug("Starting to process '{{ name }}' (normal swarm)")
            code =
              with_zip(job, rec, hops, lg) do |pack|
                one(job, pack, rec, lg)
              end
          end
          throw :"Finished processing '{{ name }}' (code=#{code})"
        end
      rescue Exception => e
        lg.error(Backtrace.new(e).to_s)
        code = 255
      end
      report(buf.to_s, code, job)
    end
  end
  'Done!'
end
