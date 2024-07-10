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

require 'securerandom'
require 'fileutils'
require 'time'
require 'aws-sdk-s3'
require 'aws-sdk-core'
require 'loog'
require 'retries'

# All factbases.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Factbases
  def initialize(key, secret, region = 'us-east-1', bucket = 'baza.zerocracy.com', loog: Loog::NULL)
    @key = key
    @secret = secret
    @region = region
    @bucket = bucket
    @loog = loog
  end

  # Save the content of this file into the cloud and return a unique ID
  # of the cloud BLOB just created.
  def save(file)
    uuid = "#{Time.now.strftime('%Y-%m-%d')}-#{SecureRandom.uuid}"
    if @key.empty?
      File.binwrite(fake(uuid), File.binread(file))
      @loog.debug("Fake saved #{file} (#{File.size(file)} bytes) into #{uuid}")
    else
      key = oname(uuid)
      File.open(file, 'rb') do |f|
        with_retries do
          aws.put_object(
            body: f,
            bucket: @bucket,
            key:
          )
        end
      end
      @loog.info("Saved to S3: #{key} (#{File.size(file)} bytes)")
    end
    uuid
  end

  # Read the BLOB from the cloud, identified by the +uuid+, and save it
  # to the file provided. Fail if there is not such BLOB.
  def load(uuid, file)
    raise 'UUID can\'t be nil' if uuid.nil?
    raise 'UUID can\'t be empty' if uuid.empty?
    if @key.empty?
      FileUtils.mkdir_p(File.dirname(file))
      File.binwrite(file, File.binread(fake(uuid)))
      @loog.debug("Fake loaded #{uuid} into #{file} (#{File.size(file)} bytes)")
    else
      key = oname(uuid)
      with_retries do
        aws.get_object(
          response_target: file,
          bucket: @bucket,
          key:
        )
      end
      @loog.info("Loaded from S3: #{key} (#{File.size(file)} bytes)")
    end
  end

  # Delete the BLOB from the cloud.
  def delete(uuid)
    raise 'UUID can\'t be nil' if uuid.nil?
    raise 'UUID can\'t be empty' if uuid.empty?
    if @key.empty?
      FileUtils.rm_f(fake(uuid))
    else
      key = oname(uuid)
      with_retries do
        aws.delete_object(
          bucket: @bucket,
          key:
        )
      end
      @loog.info("Deleted in S3: #{key}")
    end
  end

  private

  def aws
    Aws::S3::Client.new(
      region: @region,
      credentials: Aws::Credentials.new(@key, @secret)
    )
  end

  def fake(uuid)
    f = File.join('target/fbs', uuid)
    FileUtils.mkdir_p(File.dirname(f))
    f
  end

  def oname(uuid)
    uuid.split('-').join('/')
  end
end
