# frozen_string_literal: true

# Copyright (c) 2009-2024 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

$stdout.sync = true

require 'glogin'
require 'glogin/codec'
require 'haml'
require 'iri'
require 'loog'
require 'json'
require 'cgi'
require 'pgtk'
require 'pgtk/pool'
require 'raven'
require 'relative_time'
require 'sinatra'
require 'sinatra/cookies'
require 'time'
require 'yaml'
require_relative 'version'
require_relative 'objects/baza/factbases'
require_relative 'objects/baza/humans'

unless ENV['RACK_ENV'] == 'test'
  require 'rack/ssl'
  use Rack::SSL
end

configure do
  config = {
    's3' => {
      'key' => '????',
      'secret' => '????'
    },
    'telegram' => {
      'token' => '????',
      'name' => '????'
    },
    'github' => {
      'id' => '????',
      'secret' => '????',
      'encryption_secret' => ''
    }
  }
  unless ENV['RACK_ENV'] == 'test'
    f = File.join(File.dirname(__FILE__), 'config.yml')
    unless File.exist?(f)
      raise \
        "The config file #{f} is absent, can't start the app. " \
        'If you are running in a staging/testing mode, set RACK_ENV ' \
        "envirornemt variable to 'test'"
    end
    config = YAML.safe_load(File.open(f))
  end
  set :bind, '0.0.0.0'
  set :show_exceptions, false
  set :raise_errors, false
  set :dump_errors, true
  set :config, config
  set :logging, true
  set :log, Loog::REGULAR
  set :server_settings, timeout: 25
  set :glogin, GLogin::Auth.new(
    config['github']['id'],
    config['github']['secret'],
    'https://www.zerocracy.com/github-callback'
  )
  if File.exist?('target/pgsql-config.yml')
    set :pgsql, Pgtk::Pool.new(
      Pgtk::Wire::Yaml.new(File.join(__dir__, 'target/pgsql-config.yml')),
      log: settings.log
    )
  else
    set :pgsql, Pgtk::Pool.new(
      Pgtk::Wire::Env.new('DATABASE_URL'),
      log: settings.log
    )
  end
  settings.pgsql.start(4)
  set :factbases, Baza::Factbases.new(config['s3']['key'], config['s3']['secret'])
  set :humans, Baza::Humans.new(settings.pgsql)
end

get '/' do
  flash(iri.cut('/dash')) if @locals[:human]
  assemble(
    :index,
    :front,
    title: '/'
  )
end

get '/dash' do
  assemble(
    :dash,
    :default,
    title: '/dash'
  )
end

def assemble(haml, layout, map)
  haml(haml, layout: layout, locals: merged(map))
end

def the_human
  flash(iri.cut('/'), 'You have to login first') unless @locals[:human]
  @locals[:human]
end

def iri
  Iri.new(request.url)
end

require_relative 'front/front_misc'
require_relative 'front/front_errors'
require_relative 'front/front_login'
require_relative 'front/front_admin'
require_relative 'front/front_tokens'
require_relative 'front/front_jobs'
require_relative 'front/front_account'
require_relative 'front/front_push'
require_relative 'front/front_assets'
require_relative 'front/front_helpers'
