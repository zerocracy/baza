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

require_relative '../objects/baza/urror'

not_found do
  status 404
  content_type 'text/html', charset: 'utf-8'
  haml :not_found, locals: merged(
    title: request.url
  )
end

error do
  status 503
  e = env['sinatra.error']
  if e.is_a?(Baza::Urror)
    flash(@locals[:human] ? iri.cut('/dash') : iri.cut('/'), e.message, color: 'darkred')
  else
    Raven.capture_exception(e)
    assemble(
      :error,
      :default,
      title: '/error',
      error: "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
    )
  end
end

def flash(uri, msg = '', color: 'darkgreen')
  cookies[:flash_msg] = msg
  cookies[:flash_color] = color
  response.headers['X-Zerocracy-Requested'] = request.url
  response.headers['X-Zerocracy-Flash'] = msg
  redirect(uri)
end
