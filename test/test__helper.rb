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

require 'yaml'
require 'minitest/autorun'
require 'pgtk/pool'
require 'loog'
require 'securerandom'
require 'rack/test'
require 'glogin/cookie'
require 'capybara'
require 'capybara/dsl'
require_relative '../baza'
require_relative '../objects/baza/humans'

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

  def fake_pgsql
    # rubocop:disable Style/ClassVars
    @@fake_pgsql ||= Pgtk::Pool.new(
      Pgtk::Wire::Yaml.new(File.join(__dir__, '../target/pgsql-config.yml')),
      log: Loog::NULL
    ).start
    # rubocop:enable Style/ClassVars
  end

  def fake_name
    "jeff#{SecureRandom.hex(8)}"
  end

  def fake_human
    Baza::Humans.new(fake_pgsql).ensure(fake_name)
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
      fake_token(human).start(fake_name, uri, 1, 0, 'n/a', [], '127.0.0.1')
    end
  end

  def login(name = fake_name)
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
    login('tester')
    visit '/dash'
    click_link 'Start'
    tester_human.tokens.each(&:deactivate!)
  end

  def finish_all_jobs
    fbs = Baza::Factbases.new('', '', loog: Loog::NULL)
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
      puts Backtrace.new(e)
      retry
    end
  end
end
