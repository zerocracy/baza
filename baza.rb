# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2025 Zerocracy
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
require 'cgi'
require 'fileutils'
require 'glogin'
require 'glogin/codec'
require 'haml'
require 'htmlcompressor'
require 'iri'
require 'json'
require 'loog'
require 'pgtk'
require 'pgtk/pool'
require 'securerandom'
require 'sinatra'
require 'sinatra/cookies'
require 'socket'
require 'time'
require 'total'
require 'truncate'
require 'yaml'
require 'zache'
require_relative 'version'
require_relative 'objects/baza/features'

# see https://stackoverflow.com/questions/78547207
disable :method_override
use Rack::RewindableInput::Middleware
use Rack::MethodOverride
use Rack::Deflater
use HtmlCompressor::Rack, {
  enabled: true,
  remove_spaces_inside_tags: true,
  remove_multi_spaces: true,
  remove_comments: true,
  remove_intertag_spaces: false,
  remove_quotes: false
}

Haml::Template.options[:escape_html] = true
Haml::Template.options[:format] = :xhtml

unless Baza::Features::TESTS
  require 'rack/ssl'
  use Rack::SSL
end

# Sinatra configs:
configure do
  set :bind, '0.0.0.0'
  set :server_settings, timeout: 25
  set :views, File.expand_path('views', __dir__)
end

# Global config data:
configure do
  config = {
    'sentry' => '',
    'ipgeolocation' => '',
    'tg' => {
      'token' => '',
      'admin_chat' => ''
    },
    's3' => {
      'key' => '', # AWS authentication key
      'secret' => '', # AWS secret
      'region' => '', # S3 region
      'bucket' => ''
    },
    'sqs' => {
      'key' => '', # AWS authentication key
      'secret' => '', # AWS secret
      'region' => '', # SQS region
      'url' => ''
    },
    'lambda' => {
      'account' => '42424242',
      'key' => 'FAKEFAKEFAKEFAKEFAKE',
      'secret' => 'fakefakefakefakefakefakefakefakefakefake',
      'region' => 'us-east-1',
      'sgroup' => 'sg-42',
      'subnet' => 'sn-42',
      'image' => 'ami-42',
      'id_rsa' => '',
      'bucket' => 'foo'
    },
    'github' => {
      'id' => '',
      'secret' => '',
      'encryption_secret' => ''
    }
  }
  unless Baza::Features::TESTS
    f = File.join(File.dirname(__FILE__), 'config.yml')
    if File.exist?(f)
      config = YAML.safe_load(File.open(f))
      File.delete(f)
    elsif ENV['YAML_CONFIG']
      config = YAML.safe_load(ENV['YAML_CONFIG'])
    else
      raise \
        "The config file #{f} is absent, can't start the app. " \
        'Also, there is not YAML_CONFIG environment variable. ' \
        'If you are running in a staging/testing mode, set RACK_ENV ' \
        "envirornemt variable to 'test' and run again:\n" \
        'RACK_ENV=test ruby baza.app -p 8888'
    end
  end
  set :config, config
end

# Logging:
configure do
  set :logging, false # to disable default Sinatra logging and use Loog
  if Baza::Features::TESTS
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
  set :tbot, Baza::Tbot::Spy.new(
    Baza::Tbot.new(
      settings.pgsql,
      settings.config['tg']['token'],
      loog: settings.loog
    ),
    settings.config['tg']['admin_chat']
  )
  set(:tg, Always.new(1).on_error { |e, _| settings.loog.error(Backtrace.new(e)) })
  unless Baza::Features::TESTS
    settings.tg.start do
      settings.tbot.start
    end
  end
  set :telegramers, {}
end

# Humans:
configure do
  require_relative 'objects/baza/humans'
  set :humans, Baza::Humans.new(settings.pgsql, tbot: settings.tbot, loog: settings.loog)
  settings.humans.ensure('yegor256').notify(
    "🍓 New version `#{ENV.fetch('HEROKU_RELEASE_VERSION', 'n/a')}:#{Baza::VERSION}` released",
    "and started running at [#{Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address}](//dash).",
    "Ruby version is `#{RUBY_VERSION}`.",
    "PostgreSQL version is `#{settings.pgsql.version}`.",
    "Total memory on the server: #{Total::Mem.new.bytes / (1024 * 1024 * 1024)}Gb.",
    "Features: #{Baza::Features.summary}."
  )
end

# Trails:
configure do
  require_relative 'objects/baza/trails'
  set :trails, Baza::Trails.new(settings.pgsql)
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

# Amazon SQS:
configure do
  require_relative 'objects/baza/sqs'
  set :sqs, Baza::SQS.new(
    settings.config['sqs']['key'],
    settings.config['sqs']['secret'],
    settings.config['sqs']['url'],
    settings.config['sqs']['region'],
    loog: settings.loog
  )
end

# Ops with swarms:
configure do
  require_relative 'objects/baza/ec2'
  cfg = settings.config['lambda']
  ec2 = Baza::EC2.new(
    cfg['key'],
    cfg['secret'],
    cfg['region'],
    cfg['sgroup'],
    cfg['subnet'],
    type: 't2.xlarge',
    loog: settings.loog
  )
  require_relative 'objects/baza/ops'
  set :ops, Baza::Ops.new(ec2, cfg['account'], cfg['id_rsa'], cfg['bucket'])
end

# Pipeline:
configure do
  set(:pipeline, Always.new(1).on_error { |e, _| settings.loog.error(Backtrace.new(e)) })
  unless Baza::Features::TESTS || !Baza::Features::PIPELINE
    settings.pipeline.start(5) do
      load('always/always_pipeline.rb', true)
    end
  end
end

# IPGeolocation client:
configure do
  token = settings.config['ipgeolocation']
  require_relative 'objects/baza/ipgeolocation'
  set :ipgeolocation, Baza::IpGeolocation.new(
    token:,
    connection: Baza::Features::TESTS && token.empty? ? Baza::IpGeolocation::FakeConnection : Faraday
  )
end

# Garbage collection:
configure do
  set :gc, Always.new(1)
  set :expiration_days, 14
  unless Baza::Features::TESTS
    settings.gc.start(30) do
      load('always/always_gc.rb', true)
    end
  end
end

# Verify jobs:
configure do
  set :verify, Always.new(1)
  unless Baza::Features::TESTS
    settings.verify.start(60) do
      load('always/always_verify.rb', true)
    end
  end
end

# Donations:
configure do
  set :donations, Always.new(1)
  set :donation_amount, 8 * 100_000
  set :donation_period, 30
  unless Baza::Features::TESTS
    settings.donations.start(60) do
      load('always/always_donations.rb', true)
    end
  end
end

# Release all swarms:
configure do
  set :release, Always.new(1)
  unless Baza::Features::TESTS
    settings.release.start(60) do
      load('always/always_release.rb', true)
    end
  end
end

# Global in-memory cache.
configure do
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
require_relative 'front/front_trails'
require_relative 'front/front_telegram'
require_relative 'front/front_secrets'
require_relative 'front/front_durables'
require_relative 'front/front_alterations'
require_relative 'front/front_swarms'
require_relative 'front/front_push'
require_relative 'front/front_assets'
require_relative 'front/front_helpers'
