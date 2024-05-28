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
  raise Baza::Urror, 'You are not allowed to see this' unless the_human.is_admin?
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
    query: query,
    result: result,
    lag: Time.now - start
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
  human = settings.humans.ensure(params[:human])
  zents = params[:zents].to_i
  summary = params[:summary]
  human.account.add(zents, summary)
  flash(iri.cut('/account'), 'New receipt added')
end
