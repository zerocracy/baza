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

require 'liquid'
require 'fileutils'
require 'securerandom'

# Bash script for EC2 instance to build Docker image and publish to Lambda.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Recipe
  # Ctor.
  #
  # @param [Baza::Swarm] swarm The swarm
  # @param [String] id_rsa RSA private key
  # @param [Loog] loog Logging facility
  def initialize(swarm, id_rsa, bucket, loog: Loog::NULL)
    @swarm = swarm
    @id_rsa = id_rsa
    @bucket = bucket
    @loog = loog
  end

  # Make it a bash script.
  #
  # @param [Symbol] script The script to use (:release or :destroy)
  # @param [String] account AWS account number
  # @param [String] region AWS region
  # @param [String] secret Secret of the release
  # @param [String] host Host to CURL results back to
  # @return [String] Bash script to use in EC2
  def to_bash(script, account, region, secret, host: 'https://www.zerocracy.com',
    files: to_files(script, account, region, host:))
    file_of(
      'recipe.sh',
      'script' => script.to_s,
      'host' => safe(host),
      'secret' => safe(secret),
      'save_files' => [
        "\n",
        cat('id_rsa', @id_rsa),
        "\n",
        files
      ].join
    )
  end

  # Make it a bash script (without all files, but a link to them).
  #
  # @param [Symbol] script The script to use (:release or :destroy)
  # @param [String] account AWS account number
  # @param [String] region AWS region
  # @param [String] secret Secret of the release
  # @param [String] host Host to CURL results back to
  # @return [String] Bash script to use in EC2
  def to_lite(script, account, region, secret, host: 'https://www.zerocracy.com')
    to_bash(
      script, account, region, secret,
      host:,
      files: [
        'curl -s --fail-with-body ',
        "'#{host}/swarms/#{@swarm.id}/files?script=#{script}&secret=#{@swarm.secret}' ",
        '| /bin/bash'
      ].join
    )
  end

  # Make a bash script to generate files.
  #
  # @param [Symbol] script The script to use (:release or :destroy)
  # @param [String] account AWS account number
  # @param [String] region AWS region
  # @return [String] Bash script to use in EC2
  def to_files(script, account, region, host: 'https://www.zerocracy.com')
    [
      cat_of(
        "#{script}.sh",
        'version' => Baza::VERSION,
        'human' => @swarm.swarms.human.github.to_s,
        'swarm' => @swarm.id.to_s,
        'name' => safe("baza-#{@swarm.name}"),
        'github' => safe(@swarm.repository),
        'branch' => safe(@swarm.branch),
        'directory' => safe(@swarm.directory.delete_prefix('/')),
        'region' => safe(region),
        'account' => safe(account),
        'repository' => safe("#{account}.dkr.ecr.#{region}.amazonaws.com"),
        'bucket' => @bucket
      ),
      cat_of('Gemfile'),
      cat_of('entry.sh'),
      cat_of('default-entry.sh'),
      cat_of(
        'main.rb',
        'version' => Baza::VERSION,
        'account' => safe(account),
        'region' => safe(region),
        'host' => host,
        'name' => safe("baza-#{@swarm.name}"),
        'swarm' => @swarm.id.to_s,
        'secret' => @swarm.secret,
        'bucket' => @bucket
      ),
      cat_of(
        'install.sh',
        'human' => @swarm.swarms.human.github.to_s
      ),
      cat_of('Dockerfile')
    ].join
  end

  private

  def safe(txt)
    raise "Unsafe value #{txt.inspect} for bash" if txt.match?(/[\n\r\t"']/)
    txt
  end

  def file_of(file, args = {})
    dir = File.join(__dir__, '../../assets/lambda')
    Liquid::Template.parse(File.read(File.join(dir, file))).render(args)
  end

  def cat_of(file, args = {})
    txt = file_of(file, args)
    cat(file, txt)
  end

  def cat(file, txt)
    m = "EOT_#{SecureRandom.hex(8)}"
    "\ncat > #{file} <<#{m}\n#{txt.gsub('$', '\\$').gsub('`', '\\\\`')}#{txt.empty? ? '' : "\n"}#{m}\n"
  end
end
