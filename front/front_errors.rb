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

require 'backtrace'
require 'sentry-ruby'
require_relative '../objects/baza/features'
require_relative '../objects/baza/urror'
require_relative '../version'

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
  unless Baza::Features::TESTS
    Sentry.init do |c|
      c.dsn = settings.config['sentry']
      c.logger = settings.loog
      c.release = Baza::VERSION
    end
  end
end

if Baza::Features::TESTS
  get '/error' do
    raise params[:m] || 'The error is intentional'
  end
end

error do
  status 503
  e = env['sinatra.error']
  if e.is_a?(Baza::Urror)
    flash(@locals[:human] ? iri.cut('/dash') : iri.cut('/'), e.message, alert: true, code: 303)
  else
    Sentry.capture_exception(e)
    bt = Backtrace.new(e).to_s
    begin
      lines = bt.split("\n")
      loop do
        break if lines.join.length < 3500 # maximum size of TG message is 4096
        if lines.empty?
          lines = ['Backtrace was too long, completely removed']
          break
        end
        lines = lines[0..-2]
      end
      settings.tbot.notify(
        settings.humans.ensure('yegor256'),
        '🧨 I\'m sorry to tell you, but there is a crash on the server:',
        "\n```\n#{lines.map { |ln| ln.gsub('```', '...') }.join("\n")}\n```\n",
        'You better pay attention to this as soon as possible',
        'or [report](https://github.com/zerocracy/baza/issues) to the team.'
      )
    rescue StandardError => e
      # ignore it
    end
    settings.loog.error("At #{request.url}:\n#{bt}")
    response.headers['X-Zerocracy-Failure'] = e.message.inspect.gsub(/^"(.*)"$/, '\1')
    haml(:error, layout: :empty, locals: { backtrace: bt.to_s })
  end
end

def flash(uri, msg = '', alert: false, code: 302)
  raise "Multi-line message is a mistake: #{msg.inspect}" if msg =~ /[\r\n]/
  cookies[:flash_msg] = msg
  cookies[:flash_color] = alert ? 'darkred' : 'darkgreen'
  response.headers['X-Zerocracy-Requested'] = request.url
  response.headers['X-Zerocracy-Flash'] = msg
  redirect(uri, code, msg)
end
