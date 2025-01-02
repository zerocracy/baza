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

require 'json'
require_relative '../objects/baza/urror'

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

get(%r{/swarms/([0-9]+)/invocations}) do
  admin_only
  id = params['captures'].first.to_i
  swarm = the_human.swarms.get(id)
  assemble(
    :invocations,
    :default,
    title: '/invocations',
    invocations: swarm.invocations,
    offset: (params[:offset] || '0').to_i
  )
end

get(%r{/steps/([0-9]+)}) do
  admin_only
  id = params['captures'].first.to_i
  job = the_human.jobs.get(id)
  assemble(
    :steps,
    :default,
    title: '/steps',
    steps: job.steps,
    job:,
    offset: (params[:offset] || '0').to_i
  )
end

get(%r{/invocation/([0-9]+)}) do
  admin_only
  id = params['captures'].first.to_i
  assemble(
    :invocation,
    :default,
    title: '/invocation',
    invocation: the_human.invocation_by_id(id)
  )
end

get(%r{/swarms/([0-9]+)/files}) do
  id = params['captures'].first.to_i
  swarm = settings.humans.swarm_by_id(id)
  secret = params[:secret]
  return [401, "Invalid secret #{secret} for the swarm ##{swarm.id}"] if swarm.secret != secret
  settings.ops.files(swarm, params[:script].to_sym)
end

get(%r{/swarms/([0-9]+)/releases/([0-9]+)/stop}) do
  admin_only
  swarm = the_human.swarms.get(params['captures'].first.to_i)
  r = swarm.releases.get(params['captures'][1].to_i)
  r.finish!('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', nil, "stopped by @#{the_human.github}", 1, 42)
  flash(iri.cut('/swarms').append(swarm.id).append('releases'), "The release ##{r.id} was stopped")
end

get(%r{/swarms/([0-9]+)/reset}) do
  admin_only
  swarm = the_human.swarms.get(params['captures'].first.to_i)
  r = swarm.releases.each.to_a.first
  redirect(iri.cut('/swarms').append(swarm.id).append('releases').append(r[:id]).append('reset'))
end

get(%r{/swarms/([0-9]+)/releases/([0-9]+)/reset}) do
  admin_only
  swarm = the_human.swarms.get(params['captures'].first.to_i)
  r = swarm.releases.get(params['captures'][1].to_i)
  r.head!('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF')
  r.exit!(1) if r.exit.nil?
  flash(iri.cut('/swarms').append(swarm.id).append('releases'), "The SHA of the release ##{r.id} was reset")
end

put('/swarms/finish') do
  request.body.rewind
  tail = request.body.read
  secret = params[:secret]
  return 'No secret? No update!' if secret.nil? || secret.empty?
  r = settings.humans.find_release(secret)
  raise Baza::Urror, 'The "secret" is not valid, cannot find a release' if r.nil?
  head = params[:head]
  raise Baza::Urror, 'The "head" HTTP param is mandatory' if head.nil?
  version = params[:version]
  raise Baza::Urror, 'The "version" HTTP param is mandatory' if head.nil?
  code = params[:exit]
  raise Baza::Urror, 'The "exit" HTTP param is mandatory' if code.nil?
  sec = params[:sec]
  raise Baza::Urror, 'The "sec" HTTP param is mandatory' if sec.nil?
  r.finish!(head, version, tail, code.to_i, 1000 * sec.to_i)
  "The release ##{r.id} was finished"
end

post '/swarms/webhook' do
  request.body.rewind
  json =
    JSON.parse(
      case request.content_type
      when 'application/x-www-form-urlencoded'
        payload = params[:payload]
        # see https://docs.github.com/en/webhooks/using-webhooks/creating-webhooks
        if payload.nil?
          return [400, 'URL-encoded content is expected in the "payload" query parameter, but it is not provided']
        end
        payload
      when 'application/json'
        request.body.read
      else
        return [400, "Invalid content-type: #{request.content_type.inspect}"]
      end
    )
  repo = json['repository']['full_name']
  ref = json['ref']
  return "There is no 'ref'" if ref.nil?
  branch = ref.split('/')[2]
  sha = json['after']
  return [400, 'The after SHA not found'] if sha.nil?
  sha.upcase!
  swarms = settings.humans.find_swarms(repo)
  return [400, "No swarms found for #{repo.inspect}"] if swarms.empty?
  swarms.each do |swarm|
    if swarm.branch == branch
      swarm.head!(sha)
      "The swarm ##{swarm.id} of #{repo.inspect} scheduled for deployment due to changes in #{branch.inspect}"
    else
      "The swarm ##{swarm.id} doesn't watch branch #{branch.inspect}"
    end
  end.join('; ')
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
  swarm = the_human.swarms.get(id)
  settings.ops.destroy(swarm)
  swarm.enable!(false)
  flash(iri.cut('/swarms'), "The swarm ##{id} was disabled and will be destroyed soon")
end

get(%r{/swarms/([0-9]+)/reset}) do
  admin_only
  id = params['captures'].first.to_i
  the_human.swarms.get(id).head!('0000000000000000000000000000000000000000')
  flash(iri.cut('/swarms'), "The release SHA of the swarm ##{id} was reset")
end

put(%r{/swarms/([0-9]+)/invocation}) do
  id = params['captures'].first.to_i
  swarm = settings.humans.swarm_by_id(id)
  secret = params[:secret]
  return [401, "Invalid secret for the swarm ##{swarm.id}"] if swarm.secret != secret
  job_id = params[:job].to_i
  job = job_id.zero? ? nil : settings.humans.job_by_id(job_id)
  code = (params[:code] || '1').to_i
  msec = (params[:msec] || '42').to_i
  version = params[:version] || 'unknown'
  request.body.rewind
  id = swarm.invocations.register(request.body.read, code, msec, job, version)
  "Invocation ##{id} registered for swarm ##{swarm.id} (code=#{code}, msec=#{msec})"
end

post('/swarms/add') do
  admin_only
  n = params[:name]
  repo = params[:repository]
  branch = params[:branch]
  directory = params[:directory]
  s = the_human.swarms.add(n, repo, branch, directory)
  flash(iri.cut('/swarms'), "The swarm ##{s.id} #{repo}@#{branch} just added")
end

# Take a job that needs processing (or return 204 if no job).
get '/pop' do
  id = params[:swarm]&.to_i
  raise Baza::Urror, 'The "swarm" is a mandatory query param' if id.nil?
  swarm = settings.humans.swarm_by_id(id)
  secret = params[:secret]
  return [401, "Invalid secret for the swarm ##{swarm.id}"] if swarm.secret != secret
  pipe = settings.humans.pipe(settings.fbs, settings.trails)
  job = pipe.pop("swarm:##{swarm.id}/#{swarm.name}")
  return [204, 'No jobs at the moment in the pipeline'] if job.nil?
  content_type('application/zip')
  Tempfile.open do |f|
    pipe.pack(job, f.path)
    File.binread(f.path)
  end
end

# Put back the result of its processing (the body is a ZIP file).
put '/finish' do
  Tempfile.open do |f|
    request.body.rewind
    File.binwrite(f.path, request.body.read)
    id = params[:swarm]&.to_i
    raise Baza::Urror, 'The "swarm" is a mandatory query param' if id.nil?
    swarm = settings.humans.swarm_by_id(id)
    secret = params[:secret]
    return [401, "Invalid secret for the swarm ##{swarm.id}"] if swarm.secret != secret
    job_id = params[:id]&.to_i
    raise Baza::Urror, 'The "id" is a mandatory query param' if job_id.nil?
    job = settings.humans.job_by_id(job_id)
    return "The job #{job.id} is finished already" if job.finished?
    settings.humans.pipe(settings.fbs, settings.trails).unpack(job, f.path)
    "Job ##{job.id} finished, thanks!"
  end
end
