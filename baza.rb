# frozen_string_literal: true

# Copyright (c) 2009-2023 Yegor Bugayenko
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

require 'haml'
require 'loog'
require 'sinatra'
require 'yaml'
require 'iri'
require_relative 'version'

configure do
  Haml::Options.defaults[:format] = :xhtml
  config = {
    's3' => {
      'key' => '?',
      'secret' => '?',
      'bucket' => ''
    },
    'telegram' => {
      'token' => '?',
      'name' => '?'
    },
    'github' => {
      'id' => '?',
      'secret' => '?'
    }
  }
  config = YAML.safe_load(File.open(File.join(File.dirname(__FILE__), 'config.yml'))) unless ENV['RACK_ENV'] == 'test'
  set :bind, '0.0.0.0'
  set :server, :thin
  set :show_exceptions, false
  set :raise_errors, false
  set :dump_errors, false
  set :config, config
  set :logging, true
  set :log, Loog::REGULAR
  set :server_settings, timeout: 25
end

get '/' do
  haml :index, layout: :layout, locals: { title: '/' }
end

get '/robots.txt' do
  content_type 'text/plain'
  "User-agent: *\nDisallow: /"
end

get '/version' do
  content_type 'text/plain'
  Baza::VERSION
end

get '/svg/{name}' do
  content_type 'application/xml+svg'
  File.read("./public/svg/#{params[:name]}")
end

not_found do
  status 404
  content_type 'text/html', charset: 'utf-8'
  haml :not_found, layout: :layout, locals: { title: request.url }
end

error do
  status 503
  e = env['sinatra.error']
  haml(
    :error,
    layout: :layout,
    locals: {
      title: 'error',
      error: "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
    }
  )
end

def iri
  Iri.new(request.url)
end
