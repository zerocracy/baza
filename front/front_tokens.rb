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

require 'sinatra/json'

get '/tokens' do
  assemble(
    :tokens,
    :default,
    title: '/tokens',
    tokens: the_human.tokens
  )
end

get /\/tokens\/([0-9]+).json/, :provides => ['json'] do
  json(the_human.tokens.get(params['captures'].first.to_i).to_json)
end

post '/tokens/add' do
  name = params[:name]
  token = the_human.tokens.add(name)
  response.headers['X-Zerocracy-TokenId'] = token.id.to_s
  flash(iri.cut('/tokens'), "New token ##{token.id} added")
end

get /\/tokens\/([0-9]+)\/deactivate/ do
  id = params['captures'].first.to_i
  token = the_human.tokens.get(id)
  token.deactivate
  flash(iri.cut('/tokens'), "Token ##{id} deactivated")
end
