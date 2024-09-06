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

require 'backtrace'
require 'fileutils'
require 'loog'
require 'minitest/autorun'
require 'open3'
require 'random-port'
require 'webmock/minitest'
require 'yaml'
require_relative '../../objects/baza'
require_relative '../../objects/baza/recipe'
require_relative '../test__helper'

# Test for Recipe.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::RecipeTest < Minitest::Test
  def setup
    fake_pgsql.exec('TRUNCATE swarm CASCADE')
  end

  def test_generates_script
    n = fake_name
    s = fake_human.swarms.add(n, "#{fake_name}/#{fake_name}", 'master')
    bash = Baza::Recipe.new(s, '').to_bash(:release, '424242', 'us-east-1a', 'sword-fish')
    [
      "#!/bin/bash\n",
      "424242.dkr.ecr.us-east-1a.amazonaws.com/baza-#{n}",
      'RUN yum update -y',
      'gem \'aws-sdk-core\'',
      'cat > entry.rb <<EOT_',
      '"\${uri}"',
      'release.sh'
    ].each { |t| assert(bash.include?(t), "Can't find #{t.inspect} in:\n#{bash}") }
  end

  def test_runs_script
    loog = Loog::NULL
    swarm = fake_human.swarms.add('st', 'zerocracy/swarm-template', 'master')
    secret = fake_name
    r = swarm.releases.start('just start', secret)
    id_rsa_file = File.join(Dir.home, '.ssh/id_rsa')
    id_rsa = File.exist?(id_rsa_file) ? File.read(id_rsa_file) : ''
    Dir.mktmpdir do |home|
      %w[aws docker shutdown].each { |f| stub_cli(home, f) }
      FileUtils.mkdir_p(File.join(home, '.docker'))
      File.write(
        File.join(home, '.docker/Dockerfile'),
        '
        FROM ubuntu
        RUN apt-get -y update
        RUN apt-get -y install ssh-client git curl
        WORKDIR /r
        ENTRYPOINT ["/bin/bash", "recipe.sh"]
        '
      )
      img = 'test_recipe'
      bash("docker build #{File.join(home, '.docker')} -t #{img}", loog)
      begin
        RandomPort::Pool::SINGLETON.acquire do |port|
          with_front(port, loog) do
            sh = File.join(home, 'recipe.sh')
            File.write(
              sh,
              Baza::Recipe.new(swarm, id_rsa).to_bash(
                :release, 'accout', 'us-east-1', secret,
                host: "http://host.docker.internal:#{port}"
              )
            )
            bash("docker run --rm -v #{home}:/r #{img}", loog)
          end
        end
      ensure
        bash("docker rmi #{img}", loog)
      end
    end
    assert(swarm.releases.get(r.id).exit.zero?)
  end

  # This test is reproducing the entire destroy-and-release scenario
  # using real AWS account of the user who is running the test (locally).
  # It is expected that you have .aws/credentials file on your machine
  # and the account that is configured there has full access to all AWS
  # resources. The test should not make any hard. It just destroys the
  # function if it exists and then creates it again.
  def test_live_local_run
    skip
    loog = Loog::VERBOSE
    creds = File.join(Dir.home, '.aws/credentials')
    skip unless File.exist?(creds)
    s = fake_human.swarms.add('st', 'zerocracy/swarm-template', 'master')
    Dir.mktmpdir do |home|
      %w[curl shutdown].each { |f| stub_cli(home, f) }
      FileUtils.mkdir_p(File.join(home, '.aws'))
      FileUtils.copy(creds, File.join(home, '.aws/credentials'))
      sh = File.join(home, 'recipe.sh')
      %i[destroy release].each do |step|
        File.write(
          sh,
          Baza::Recipe.new(s, '').to_bash(step, '019644334823', 'us-east-1', 'fake')
        )
        stdout = bash("/bin/bash #{sh}", loog)
        assert(stdout.include?('exit=0&'))
      end
    end
  end

  def test_build_docker_image
    loog = Loog::VERBOSE
    Dir.mktmpdir do |home|
      ['Dockerfile', 'Gemfile', 'entry.rb', 'install-pgsql.sh', 'install.sh'].each do |f|
        FileUtils.copy(
          File.join(File.join(__dir__, '../../assets/lambda'), f),
          File.join(home, f)
        )
      end
      FileUtils.mkdir_p(File.join(home, 'swarm'))
      bash("docker build #{home} -t test_recipe", loog)
    ensure
      bash('docker rmi -f test_recipe', loog)
    end
  end

  def test_fake_docker_run
    skip
    WebMock.enable_net_connect!
    loog = Loog::NULL
    Dir.mktmpdir do |home|
      File.write(
        File.join(home, 'Dockerfile'),
        Liquid::Template.parse(
          File.read(File.join(__dir__, '../../assets/lambda/Dockerfile'))
        ).render('from' => 'public.ecr.aws/lambda/ruby:3.2')
      )
      ['install-pgsql.sh', 'install.sh', 'entry.rb', 'Gemfile'].each do |f|
        FileUtils.copy(File.join(File.join(__dir__, '../../assets/lambda'), f), File.join(home, f))
      end
      FileUtils.mkdir_p(File.join(home, 'swarm'))
      File.write(File.join(home, 'swarm/Gemfile'), "source 'https://rubygems.org'\ngem 'tago'")
      bash("docker build #{home} -t image-test", loog)
      ret =
        RandomPort::Pool::SINGLETON.acquire do |port|
          stdout = bash("docker run -d -p #{port}:8080 image-test", loog)
          container = stdout.split("\n")[-1]
          loog.debug("Docker container started: #{container}")
          begin
            sleep 1
            request = Typhoeus::Request.new(
              "http://localhost:#{port}/2015-03-31/functions/function/invocations",
              body: '{}',
              method: :get
            )
            request.run
            bash("docker logs #{container}", loog)
            request.response
          ensure
            bash("docker rm -f #{container}", loog)
          end
        end
      assert_equal(200, ret.response_code, ret.response_body)
      assert_equal('"Done!"', ret.response_body, ret.response_body)
    end
  end

  private

  def with_front(port, loog)
    started = false
    pid = nil
    server =
      Thread.new do
        Open3.popen2e({}, "ruby baza.rb -p #{port}") do |stdin, stdout, thr|
          pid = thr.pid
          stdin.close
          until stdout.eof?
            begin
              ln = stdout.gets
            rescue IOError => e
              ln = Backtrace.new(e).to_s
            end
            loog.debug(ln)
            started |= ln.include?("has taken the stage on #{port}")
          end
        end
      rescue StandardError => e
        loog.error(Backtrace.new(e))
        raise e
      end
    loop do
      sleep 0.1
      break if started
    end
    begin
      yield
    ensure
      Process.kill('QUIT', pid)
      server.join
    end
  end

  def bash(cmd, loog, env = {})
    loog.debug("+ #{cmd}")
    buf = ''
    Open3.popen2e(env, cmd) do |stdin, stdout, thr|
      stdin.close
      until stdout.eof?
        begin
          ln = stdout.gets
        rescue IOError => e
          ln = Backtrace.new(e).to_s
        end
        loog.debug(ln)
        buf += ln
      end
      assert(thr.value.to_i.zero?)
    end
    buf
  end

  def stub_cli(home, name)
    sh = File.join(home, name)
    File.write(sh, 'echo FAKE-$(basename $0) $@')
    FileUtils.chmod('+x', sh)
  end
end
