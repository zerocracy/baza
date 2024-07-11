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

$stdout.sync = true

require 'always'
require 'glogin'
require 'glogin/codec'
require 'haml'
require 'iri'
require 'fileutils'
require 'loog'
require 'json'
require 'cgi'
require 'pgtk'
require 'pgtk/pool'
require 'sinatra'
require 'sinatra/cookies'
require 'time'
require 'truncate'
require 'yaml'
require 'zache'
require_relative 'version'

# see https://stackoverflow.com/questions/78547207
disable :method_override
use Rack::RewindableInput::Middleware
use Rack::MethodOverride

unless ENV['RACK_ENV'] == 'test'
  require 'rack/ssl'
  use Rack::SSL
end

# Sinatra configs:
configure do
  set :bind, '0.0.0.0'
  set :server_settings, timeout: 25
end

# Global config data:
configure do
  config = {
    'sentry' => '',
    'tg_token' => '',
    's3' => {
      'key' => '',
      'secret' => '',
      'region' => '',
      'bucket' => ''
    },
    'github' => {
      'id' => '',
      'secret' => '',
      'encryption_secret' => ''
    }
  }
  unless ENV['RACK_ENV'] == 'test'
    f = File.join(File.dirname(__FILE__), 'config.yml')
    unless File.exist?(f)
      raise \
        "The config file #{f} is absent, can't start the app. " \
        'If you are running in a staging/testing mode, set RACK_ENV ' \
        "envirornemt variable to 'test' and run again:\n" \
        'RACK_ENV=test ruby baza.app -p 8888'
    end
    config = YAML.safe_load(File.open(f))
  end
  set :config, config
end

# Logging:
configure do
  set :show_exceptions, false
  set :raise_errors, false
  set :dump_errors, true
  set :logging, false # to disable default Sinatra logging and use Loog
  if ENV['RACK_ENV'] == 'test'
    set :loog, Loog::NULL
  else
    set :loog, Loog::VERBOSE
  end
end

# PostgreSQL:
configure do
  if File.exist?('target/pgsql-config.yml')
    set :pgsql, Pgtk::Pool.new(
      Pgtk::Wire::Yaml.new(File.join(__dir__, 'target/pgsql-config.yml')),
      log: settings.loog
    )
  else
    set :pgsql, Pgtk::Pool.new(
      Pgtk::Wire::Env.new('DATABASE_URL'),
      log: settings.loog
    )
  end
  settings.pgsql.start(4)
end

# Telegram client:
configure do
  require_relative 'objects/baza/tbot'
  set :tbot, Baza::Tbot.new(settings.pgsql, settings.config['tg_token'], loog: settings.loog)
  settings.tbot.start unless ENV['RACK_ENV'] == 'test'
end

# Humans:
configure do
  require_relative 'objects/baza/humans'
  set :humans, Baza::Humans.new(settings.pgsql, tbot: settings.tbot)
end

# Factbases:
configure do
  require_relative 'objects/baza/factbases'
  set :fbs, Baza::Factbases.new(
    settings.config['s3']['key'],
    settings.config['s3']['secret'],
    settings.config['s3']['region'],
    settings.config['s3']['bucket'],
    loog: settings.loog
  )
end

# Pipeline:
configure do
  require_relative 'objects/baza/pipeline'
  lib = File.absolute_path(File.join(__dir__, ENV['RACK_ENV'] == 'test' ? 'target/j' : 'j'))
  ['', 'lib', 'judges'].each { |d| FileUtils.mkdir_p(File.join(lib, d)) }
  set :pipeline, Baza::Pipeline.new(lib, settings.humans, settings.fbs, settings.loog, tbot: settings.tbot)
  settings.pipeline.start unless ENV['RACK_ENV'] == 'test'
end

# Garbage collection:
configure do
  set :gc, Always.new(1)
  set :expiration_days, 14
  settings.gc.start(30) do
    settings.humans.gc.ready_to_expire(settings.expiration_days) do |j|
      j.expire!(settings.fbs)
      settings.loog.debug("Job ##{j.id} is garbage, expired")
    end
    settings.humans.gc.stuck(60) do |j|
      j.expire!(settings.fbs)
      settings.loog.debug("Job ##{j.id} was stuck, expired")
    end
  end
end

# Donations:
configure do
  set :donations, Always.new(1)
  set :donation_amount, 8 * 100_000
  set :donation_period, 30
  settings.donations.start(60) do
    settings.humans.donate(
      amount: settings.donation_amount,
      days: settings.donation_period
    )
  end
end

# Login and others:
configure do
  set :glogin, GLogin::Auth.new(
    settings.config['github']['id'],
    settings.config['github']['secret'],
    'https://www.zerocracy.com/github-callback'
  )
  set :zache, Zache.new
end

get '/' do
  flash(iri.cut('/dash')) if @locals[:human]
  assemble(:index, :front, title: '/')
end

get '/dash' do
  assemble(:dash, :default, title: '/dash')
end

require_relative 'front/front_misc'
require_relative 'front/front_errors'
require_relative 'front/front_login'
require_relative 'front/front_admin'
require_relative 'front/front_tokens'
require_relative 'front/front_jobs'
require_relative 'front/front_account'
require_relative 'front/front_valves'
require_relative 'front/front_locks'
require_relative 'front/front_telegram'
require_relative 'front/front_secrets'
require_relative 'front/front_push'
require_relative 'front/front_assets'
require_relative 'front/front_helpers'
