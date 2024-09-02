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

require 'get_process_mem'
require 'total'
require 'sys-cpu'
require_relative '../version'

before '/*' do
  @locals = {
    http_start: Time.now,
    github_login_link: settings.glogin.login_uri,
    request_ip: request.ip,
    db_size: settings.zache.get(:db_size, lifetime: 30 * 60) do
      settings.pgsql.exec(
        'SELECT pg_size_pretty(pg_database_size(current_database())) AS s'
      )[0]['s'].gsub(' ', '')
    end,
    pgsql_version: settings.zache.get(:pgsql_version, lifetime: 60 * 60) do
      settings.pgsql.version
    end,
    mem: settings.zache.get(:mem, lifetime: 60) { GetProcessMem.new.bytes.to_i },
    total_mem: settings.zache.get(:total_mem, lifetime: 60) { Total::Mem.new.bytes },
    load_avg: Sys::CPU.load_avg[0]
  }
end

after do
  response.headers['X-Zerocracy-Version'] = Baza::VERSION
end

get '/robots.txt' do
  content_type 'text/plain'
  "User-agent: *\nDisallow: /"
end

get '/version' do
  content_type 'text/plain'
  Baza::VERSION
end

def merged(hash)
  out = @locals.merge(hash)
  out[:local_assigns] = out
  if cookies[:flash_msg]
    out[:flash_msg] = cookies[:flash_msg]
    cookies.delete(:flash_msg)
  end
  out[:flash_color] = cookies[:flash_color] || 'good'
  cookies.delete(:flash_color)
  out
end

def assemble(haml, layout, map)
  haml(haml, layout:, locals: merged(map))
end

def iri
  Iri.new(request.url)
end
