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
require 'net/ssh'
require 'net/scp'
require 'openssl'

# Shell to a server.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Shell
  # Ctor.
  #
  # @param [String] key SSH private key
  # @param [Loog] loog Logging facility
  # @param [String] user Login
  # @param [Integer] port TCP port
  def initialize(key, user, port, loog: Loog::NULL)
    key = key.gsub(/\n +/, "\n")
    OpenSSL::PKey.read(key) # sanity check
    @key = key
    @loog = loog
    @user = user
    @port = port
  end

  # @param [String] ip IP address of the server
  def connect(ip)
    Net::SSH.start(ip, @user, port: @port, keys: [], key_data: [@key], keys_only: true, timeout: 60_000) do |ssh|
      @loog.debug("Logged into #{ip} as #{@user.inspect}")
      yield Session.new(ssh, @loog)
    end
  rescue Net::SSH::Disconnect => e
    @loog.warn("There is a temporary error, will retry: #{e.message}")
    retry
  end

  class Session
    def initialize(ssh, loog)
      @ssh = ssh
      @loog = loog
    end

    def upload_file(path, content)
      Tempfile.open do |f|
        File.write(f.path, content)
        upload(f.path, path)
      end
    end

    # Build a new Docker image in a new EC2 server and publish it to
    # Lambda function.
    def upload(file, path)
      @ssh.scp.upload!(file, path)
      @loog.debug("#{File.basename(file)} (#{File.size(file)} bytes) uploaded to #{path}")
    end

    # @param [String] cmd The command to run
    # @return [Integer] Exit code
    def exec(cmd)
      stdout = ''
      code = nil
      @ssh.open_channel do |channel|
        channel.exec(cmd) do |ch, success|
          ch.on_data do |_, data|
            stdout += data
            lines = stdout.split(/\n/, -1)
            lines[..-2].each do |ln|
              @loog.debug(ln.strip)
            end
            stdout = lines[-1]
          end
          ch.on_request('exit-status') do |_, data|
            code = data.read_long
          end
        end
      end
      @ssh.loop
      code
    end
  end
end
