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

unless ENV['RACK_ENV'] == 'test'
  require 'rack/ssl'
  use Rack::SSL
end

configure do
  config = {
    'aws' => {
      'key' => '????',
      'secret' => '????'
    },
    'telegram' => {
      'token' => '????',
      'name' => '????'
    },
    'github' => {
      'client_id' => '????',
      'client_secret' => '????',
      'encryption_secret' => ''
    }
  }
  unless ENV['RACK_ENV'] == 'test'
    f = File.join(File.dirname(__FILE__), 'config.yml')
    unless File.exist?(f)
      raise [
        "The config file #{f} is absent, can't start the app. ",
        "If you are running in a staging/testing mode, set RACK_ENV envirornemt variable to 'test'"
      ].join
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
    config['github']['client_id'],
    config['github']['client_secret'],
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
end

get '/' do
  flash(iri.cut('/dash')) if @locals[:human]
  haml :index, layout: :front, locals: merged(title: '/')
end

get '/dash' do
  haml :dash, layout: :default, locals: { title: '/dash' }
end

get '/jobs' do
  haml :jobs, layout: :default, locals: { title: '/jobs' }
end

get '/robots.txt' do
  content_type 'text/plain'
  "User-agent: *\nDisallow: /"
end

get '/version' do
  content_type 'text/plain'
  Baza::VERSION
end

not_found do
  status 404
  content_type 'text/html', charset: 'utf-8'
  haml :not_found, layout: :default, locals: { title: request.url }
end

error do
  status 503
  e = env['sinatra.error']
  haml(
    :error,
    layout: :default,
    locals: {
      title: 'error',
      error: "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
    }
  )
end

get '/sql' do
  raise Urror::Nb, 'You are not allowed to see this' unless current_human.admin?
  query = params[:query] || 'SELECT * FROM human LIMIT 5'
  start = Time.now
  result = settings.pgsql.exec(query)
  haml :sql, layout: :layout, locals: merged(
    title: '/sql',
    query: query,
    result: result,
    lag: Time.now - start
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
require_relative 'front/front_tokens'
require_relative 'front/front_assets'
