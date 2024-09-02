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

def admin_only
  raise Baza::Urror, 'You are not allowed to see this' unless the_human.admin?
end

get '/relogin' do
  admin_only
  assemble(
    :relogin,
    :default,
    title: '/relogin'
  )
end

post '/relogin' do
  admin_only
  login = params[:u]
  cookies[:auth] = GLogin::Cookie::Open.new(
    {
      'id' => settings.humans.ensure(login).id.to_s,
      'login' => login,
      'avatar_url' => 'none'
    },
    settings.config['github']['encryption_secret']
  ).to_s
  flash(iri.cut('/dash'), "You have been logged in as @#{login} (be careful!)")
end

get '/sql' do
  admin_only
  query = params[:query] || 'SELECT * FROM human LIMIT 5'
  start = Time.now
  result = settings.pgsql.exec(query)
  assemble(
    :sql,
    :default,
    title: '/sql',
    query:,
    result:,
    lag: Time.now - start
  )
end

get '/bash' do
  admin_only
  command = params[:command] || 'echo "Hello, world!"'
  assemble(
    :bash,
    :default,
    title: '/bash',
    command:,
    stdout: `set -ex; (#{command}) 2>&1`
  )
end

get '/gift' do
  admin_only
  assemble(
    :gift,
    :default,
    title: '/gift'
  )
end

post '/gift' do
  admin_only
  login = params[:human]
  raise Baza::Urror, 'The "human" form part is missing' if login.nil?
  human = settings.humans.ensure(login)
  zents = params[:zents].to_i
  raise Baza::Urror, 'The amount can\'t be zero' if zents.nil?
  summary = params[:summary]
  human.account.top_up(zents, summary)
  flash(iri.cut('/account'), 'New receipt added')
end

get '/footer/status' do
  admin_only
  b = params[:badge]
  content_type 'text/plain'
  settings.send(b).backtraces.map { |bt| Backtrace.new(bt).to_s }.join("\n\n")
end
