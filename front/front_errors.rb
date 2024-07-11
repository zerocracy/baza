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

require_relative '../objects/baza/urror'

configure do
  set :show_exceptions, false
  set :raise_errors, false
  set :dump_errors, true
end

not_found do
  status 404
  content_type('text/html', charset: 'utf-8')
  assemble(:not_found, :empty, url: request.url)
end

configure do
  if ENV['RACK_ENV'] != 'test'
    require 'raven'
    Raven.configure do |c|
      c.dsn = settings.config['sentry']
      require_relative '../version'
      c.release = Baza::VERSION
    end
  end
end

if ENV['RACK_ENV'] == 'test'
  get '/error' do
    raise 'The error is intentional'
  end
end

error do
  status 503
  e = env['sinatra.error']
  if e.is_a?(Baza::Urror)
    flash(@locals[:human] ? iri.cut('/dash') : iri.cut('/'), e.message, color: 'darkred', code: 303)
  else
    require 'raven'
    Raven.capture_exception(e)
    bt = Backtrace.new(e)
    settings.loog.error("At #{request.url}:\n#{bt}")
    response.headers['X-Zerocracy-Failure'] = e.message
    haml(:error, layout: :empty, locals: { backtrace: bt.to_s })
  end
end

def flash(uri, msg = '', color: 'darkgreen', code: 302)
  cookies[:flash_msg] = msg
  cookies[:flash_color] = color
  response.headers['X-Zerocracy-Requested'] = request.url
  response.headers['X-Zerocracy-Flash'] = msg
  redirect(uri, code)
end
