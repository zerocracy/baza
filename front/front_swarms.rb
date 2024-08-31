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

get '/swarms' do
  admin_only
  assemble(
    :swarms,
    :default,
    title: '/swarms',
    swarms: the_human.swarms,
    offset: (params[:offset] || '0').to_i
  )
end

post '/swarms/webhook' do
  # if it's not PUSH event, ignore it and return 200
  json = {} # take it
  repo = json[:repository]
  branch = json[:branch]
  swarm = settings.humans.find_swarm(repo, branch)
  return "The swarm not found for #{repo}@#{branch}" if swarm.nil?
  swarm.dirty!(true)
  "The swarm ##{swarm.id} of #{repo}@#{branch} scheduled for deployment, thanks!"
end

get(%r{/swarms/([0-9]+)/remove}) do
  admin_only
  id = params['captures'].first.to_i
  the_human.swarms.get(id).remove
  flash(iri.cut('/swarms'), "The swarm ##{id} just removed")
end

get(%r{/swarms/([0-9]+)/reset}) do
  admin_only
  id = params['captures'].first.to_i
  the_human.swarms.get(id).release!('0000000000000000000000000000000000000000')
  flash(iri.cut('/swarms'), "The release SHA of the swarm ##{id} was reset")
end

post('/swarms/add') do
  admin_only
  n = params[:name]
  repo = params[:repository]
  branch = params[:branch]
  id = the_human.swarms.add(n, repo, branch)
  flash(iri.cut('/swarms'), "The swarm ##{id} #{repo}@#{branch} just added")
end
