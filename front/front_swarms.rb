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

get(%r{/swarms/([0-9]+)/releases}) do
  admin_only
  id = params['captures'].first.to_i
  swarm = the_human.swarms.get(id)
  assemble(
    :releases,
    :default,
    title: '/releases',
    releases: swarm.releases,
    offset: (params[:offset] || '0').to_i
  )
end

get(%r{/swarms/([0-9]+)/releases/([0-9]+)/stop}) do
  admin_only
  swarm = the_human.swarms.get(params['captures'].first.to_i)
  r = swarm.releases.get(params['captures'][1].to_i)
  r.finish!('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', "stopped by @#{the_human.github}", 1, 42)
  flash(iri.cut('/swarms').append(swarm.id).append('releases'), "The release ##{r.id} was stopped")
end

put('/swarms/finish') do
  secret = params[:secret]
  return 'No secret? No update!' if secret.nil? || secret.empty?
  request.body.rewind
  r = settings.humans.find_release(secret)
  raise Baza::Urror, 'The "secret" is not valid, cannot find a release' if r.nil?
  head = params[:head]
  raise Baza::Urror, 'The "head" HTTP param is mandatory' if head.nil?
  code = params[:exit]
  raise Baza::Urror, 'The "exit" HTTP param is mandatory' if code.nil?
  sec = params[:sec]
  raise Baza::Urror, 'The "sec" HTTP param is mandatory' if sec.nil?
  r.finish!(head, request.body.read, code.to_i, 1000 * sec.to_i)
  flash(iri.cut('/swarms'), "The release ##{r.id} was finished")
end

post '/swarms/webhook' do
  # if it's not PUSH event, ignore it and return 200
  json = {} # take it
  repo = json[:repository]
  branch = json[:branch]
  swarm = settings.humans.find_swarm(repo, branch)
  return "The swarm not found for #{repo}@#{branch}" if swarm.nil?
  swarm.head!('0000000000000000000000000000000000000000')
  "The swarm ##{swarm.id} of #{repo}@#{branch} scheduled for deployment, thanks!"
end

get(%r{/swarms/([0-9]+)/enable}) do
  admin_only
  id = params['captures'].first.to_i
  the_human.swarms.get(id).enable!(true)
  flash(iri.cut('/swarms'), "The swarm ##{id} was enabled")
end

get(%r{/swarms/([0-9]+)/disable}) do
  admin_only
  id = params['captures'].first.to_i
  the_human.swarms.get(id).enable!(false)
  flash(iri.cut('/swarms'), "The swarm ##{id} was disabled")
end

get(%r{/swarms/([0-9]+)/reset}) do
  admin_only
  id = params['captures'].first.to_i
  the_human.swarms.get(id).head!('0000000000000000000000000000000000000000')
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
