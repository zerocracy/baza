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

ENV['RACK_ENV'] = 'test'

require 'simplecov'
SimpleCov.start

require 'simplecov-cobertura'
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

require 'minitest/reporters'
Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

require 'capybara'
require 'capybara/dsl'
require 'glogin/cookie'
require 'loog'
require 'minitest/autorun'
require 'open3'
require 'pgtk/pool'
require 'rack/test'
require 'retries'
require 'securerandom'
require 'tago'
require 'yaml'
require_relative '../baza'
require_relative '../objects/baza/humans'
require_relative '../objects/baza/pipeline'

module Rack
  module Test
    class Session
      def default_env
        { 'REMOTE_ADDR' => '127.0.0.1', 'HTTPS' => 'on' }.merge(headers_for_env)
      end
    end
  end
end

class Minitest::Test
  include Rack::Test::Methods
  include Capybara::DSL

  def setup
    require 'sinatra'
    Capybara.app = Sinatra::Application.new
    page.driver.header 'User-Agent', 'Capybara'
  end

  def fake_live_cfg
    # It is configured in Rackfile:
    file = ENV.fetch('RACK_LIVE_YAML_FILE', nil)
    skip if file.nil?
    skip unless File.exist?(file)
    YAML.safe_load(File.open(file))
  end

  def fake_loog
    ENV['RACK_RUN'] ? Loog::ERRORS : Loog::VERBOSE
  end

  def fake_pgsql
    # rubocop:disable Style/ClassVars
    @@fake_pgsql ||= Pgtk::Pool.new(
      Pgtk::Wire::Yaml.new(File.join(__dir__, '../target/pgsql-config.yml')),
      log: fake_loog
    ).start
    @@fake_pgsql.exec('SET client_min_messages TO WARNING;')
    @@fake_pgsql
    # rubocop:enable Style/ClassVars
  end

  def fake_name
    "fake#{SecureRandom.hex(8)}"
  end

  def fake_humans
    Baza::Humans.new(fake_pgsql)
  end

  def fake_human(name = fake_name)
    fake_humans.ensure(name)
  end

  def fake_token(human = fake_human)
    human.tokens.add(fake_name)
  end

  def fake_job(human = fake_human)
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
    Dir.mktmpdir do |dir|
      input = File.join(dir, 'foo.fb')
      File.binwrite(input, Factbase.new.export)
      uri = fbs.save(input)
      fake_token(human).start(
        fake_name, uri, 1, 0, 'n/a',
        [
          'duration:360',
          'workflow_url:https://google.com',
          'vitals_url:https://twitter.com'
        ],
        '127.0.0.1'
      )
    end
  end

  def fake_login(name = fake_name)
    enc = GLogin::Cookie::Open.new(
      { 'login' => name, 'id' => app.humans.ensure(name).id.to_s },
      ''
    ).to_s
    set_cookie("auth=#{enc}")
  end

  def assert_status(code)
    assert_equal(
      code, last_response.status,
      "#{last_request.url}:\n#{last_response.headers}\n#{last_response.body}"
    )
  end

  def tester_human
    app.humans.ensure('tester')
  end

  def start_as_tester
    fake_login('tester')
    visit '/dash'
    click_link 'Start'
    tester_human.tokens.each(&:deactivate!)
  end

  def finish_all_jobs
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
    retries = 0
    loop do
      Dir.mktmpdir do |home|
        FileUtils.mkdir_p(File.join(home, 'judges'))
        pp = Baza::Pipeline.new(home, Baza::Humans.new(fake_pgsql), fbs, Loog::NULL, Baza::Trails.new(fake_pgsql))
        count = 0
        loop do
          break unless pp.process_one
          count += 1
          raise 'Too many, definitely an error' if count > 100
        end
      end
      break
    rescue StandardError => e
      retries += 1
      raise e if retries > 100
      retry
    end
  end

  def fake_aws(cmd, hash)
    stub_request(:post, 'https://ec2.us-east-1.amazonaws.com/')
      .with(body: /#{cmd}/)
      .to_return(body: to_aws_response(cmd, hash))
  end

  def to_aws_response(cmd, hash)
    "<#{cmd}Response>#{to_xml(hash)}</#{cmd}Response>"
  end

  def to_xml(hash)
    hash.map do |k, v|
      "<#{k}>#{v.is_a?(Hash) ? to_xml(v) : v}</#{k}>"
    end.join
  end

  def fake_front(port, loog: Loog::NULL)
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

  def fake_image(dir)
    img = fake_name
    qbash("docker build #{Shellwords.escape(dir)} -t #{img}", log: fake_loog)
    begin
      yield img
    ensure
      qbash("docker rmi #{img}", log: fake_loog, timeout: 10)
    end
  end

  def fake_container(image, args = '', cmd = '', loog: fake_loog, env: {})
    n = fake_name
    stdout = nil
    code = nil
    begin
      stdout, code = qbash(
        [
          'docker run',
          "--name #{Shellwords.escape(n)}",
          '--add-host host.docker.internal:host-gateway',
          args,
          env.keys.map { |k| "-e #{Shellwords.escape(k)}" }.join(' '),
          '--user', Shellwords.escape("#{Process.uid}:#{Process.gid}"),
          Shellwords.escape(image),
          cmd
        ],
        timeout: 25,
        log: loog,
        accept: nil,
        both: true,
        env:
      )
      unless code.zero?
        fake_loog.error(stdout)
        raise \
          "Failed to run docker container #{n} with #{image}, " \
          "exit code is ##{code}, stdout has #{stdout.split("\n").count} lines"
      end
      return yield n if block_given?
    ensure
      qbash(
        "docker logs #{Shellwords.escape(n)}",
        level: code.zero? ? Logger::DEBUG : Logger::ERROR,
        log: fake_loog
      )
      qbash("docker rm -f #{Shellwords.escape(n)}", log: fake_loog)
    end
    stdout
  end

  def wait_for(seconds = 20)
    start = Time.now
    loop do
      raise "Timed out after waiting for #{start.ago}" if Time.now - start > seconds
      break if yield
    end
  end

  def assert_include(text, *subs)
    subs.each do |s|
      assert(text.include?(s), "Can't find #{s.inspect} in\n#{text}")
    end
  end
end
