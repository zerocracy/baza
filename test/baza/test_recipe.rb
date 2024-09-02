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

require 'minitest/autorun'
require 'fileutils'
require 'loog'
require 'yaml'
require 'webmock/minitest'
require_relative '../test__helper'
require_relative '../../objects/baza'
require_relative '../../objects/baza/recipe'

# Test for Recipe.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::RecipeTest < Minitest::Test
  def setup
    fake_pgsql.exec('DELETE FROM swarm')
  end

  def test_generates_script
    s = fake_human.swarms.add(fake_name, "#{fake_name}/#{fake_name}", 'master')
    bash = Baza::Recipe.new(s, '').to_bash('accout', 'us-east-1', '0.0.0', 'sword-fish')
    [
      'FROM accout.dkr.ecr.us-east-1.amazonaws.com/zerocracy/baza:0.0.0',
      'RUN yum update -y',
      'gem \'aws-sdk-core\'',
      'cat > entry.rb <<EOT_'
    ].each { |t| assert(bash.include?(t), t) }
  end

  def test_runs_script
    loog = Loog::NULL
    s = fake_human.swarms.add('st', 'zerocracy/swarm-template', 'master')
    Dir.mktmpdir do |home|
      %w[aws docker shutdown curl].each do |f|
        sh = File.join(home, f)
        File.write(sh, 'echo FAKE-$(basename $0) $@')
        FileUtils.chmod('+x', sh)
      end
      sh = File.join(home, 'recipe.sh')
      File.write(
        sh,
        Baza::Recipe.new(s, '').to_bash('accout', 'us-east-1', '0.0.0', 'sword-fish')
      )
      bash("/bin/bash #{sh}", loog)
    end
  end

  def test_live_deploy
    skip # use if very very carefully!
    loog = Loog::VERBOSE
    yml = '/code/home/assets/zerocracy/baza.yml'
    skip unless File.exist?(yml)
    cfg = YAML.safe_load(File.open(yml))['lambda']
    swarm = fake_human.swarms.add('st', 'zerocracy/swarm-template', 'master')
    WebMock.enable_net_connect!
    ec2 = Baza::EC2.new(
      cfg['key'],
      cfg['secret'],
      cfg['region'],
      cfg['sgroup'],
      cfg['subnet'],
      cfg['image'],
      loog:
    )
    instance = ec2.run(Baza::Recipe.new(swarm).to_bash(cfg['account'], cfg['region'], 'latest', ''))
    assert(instance.start_with?('i-'))
  end

  def test_fake_docker_run
    WebMock.enable_net_connect!
    loog = Loog::VERBOSE
    Dir.mktmpdir do |home|
      File.write(
        File.join(home, 'Dockerfile'),
        Liquid::Template.parse(
          File.read(File.join(__dir__, '../../assets/lambda/Dockerfile'))
        ).render('from' => '')
      )
      ['install-pgsql.sh', 'install.sh', 'entry.rb', 'Gemfile'].each do |f|
        FileUtils.copy(File.join(File.join(__dir__, '../../assets/lambda'), f), File.join(home, f))
      end
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

  def bash(cmd, loog)
    loog.debug("+ #{cmd}")
    stdout = `#{cmd} 2>&1`
    loog.debug(stdout)
    assert_equal(0, $CHILD_STATUS.exitstatus, stdout)
    stdout
  end

  def stub(cmd, hash)
    xml = "<#{cmd}Response>#{to_xml(hash)}</#{cmd}Response>"
    stub_request(:post, 'https://ec2.us-east-1.amazonaws.com/')
      .with(body: /#{cmd}/)
      .to_return(body: xml)
  end

  def to_xml(hash)
    hash.map do |k, v|
      "<#{k}>#{v.is_a?(Hash) ? to_xml(v) : v}</#{k}>"
    end.join
  end

  def when_ready(port)
    sleep 1
    port
  end
end
