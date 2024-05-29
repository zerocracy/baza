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

require 'fileutils'
require_relative '../objects/baza/urror'

get '/push' do
  assemble(
    :push,
    :default,
    title: '/push',
    token: the_human.tokens.size == 1 ? the_human.tokens.to_a[0].text : ''
  )
end

post '/push' do
  text = params[:token]
  raise Baza::Urror, 'The "token" form part is missing' if text.nil?
  token = the_human.tokens.find(text)
  tfile = params[:factbase]
  raise Baza::Urror, 'The "factbase" form part is missing' if tfile.nil?
  name = params[:name]
  raise Baza::Urror, 'The "name" form part is missing' if name.nil?
  Tempfile.open do |f|
    FileUtils.copy(tfile[:tempfile], f.path)
    File.delete(tfile[:tempfile])
    fid = settings.fbs.save(f.path)
    job = token.start(name, fid)
    settings.loog.info("New push arrived via HTTP POSt, job ID is #{job.id}")
    flash(iri.cut('/jobs'), "New job ##{job.id} started")
  end
end

put(%r{/push/([a-z0-9-]+)}) do
  text = request.env['HTTP_X_ZEROCRACY_TOKEN']
  raise Baza::Urror, 'The "X-Zerocracy-Token" HTTP header with a token is missing' if text.nil?
  token = settings.humans.his_token(text)
  name = params['captures'].first
  Tempfile.open do |f|
    request.body.rewind
    File.binwrite(f, request.body.read)
    fid = settings.fbs.save(f.path)
    job = token.start(name, fid)
    settings.loog.info("New push arrived via HTTP PUT, job ID is #{job.id}")
    job.id.to_s
  end
end

# What is the most newest Job ID with this name?
get(%r{/recent/([a-z0-9-]+).txt}) do
  content_type('text/plain')
  the_human.jobs.recent(params['captures'].first).id.to_s
end

# Factbase artifact of this job exists?
get(%r{/exists/([a-z0-9-]+)}) do
  content_type('text/plain')
  the_human.jobs.name_exists?(params['captures'].first) ? 'yes' : 'no'
end

# Read the output of this job.
get(%r{/stdout/([0-9]+).txt}) do
  r = the_human.jobs.get(params['captures'].first.to_i).result
  content_type('text/plain')
  r.stdout
end

# The job is finished?
get(%r{/finished/([0-9]+)}) do
  j = the_human.jobs.get(params['captures'].first.to_i)
  content_type('text/plain')
  j.finished? ? 'yes' : 'no'
end

get(%r{/pull/([0-9]+).fb}) do
  j = the_human.jobs.get(params['captures'].first.to_i)
  r = j.result
  raise Baza::Urror, "The job ##{j.id} is expired" if j.expired?
  raise Baza::Urror, 'The result is empty' if r.empty?
  raise Baza::Urror, 'The result is broken' unless r.exit.zero?
  Tempfile.open do |f|
    settings.fbs.load(r.uri2, f.path)
    content_type('application/octet-stream')
    File.binread(f.path)
  end
end

get(%r{/inspect/([0-9]+).fb}) do
  j = the_human.jobs.get(params['captures'].first.to_i)
  raise Baza::Urror, "The job ##{j.id} is expired" if j.expired?
  Tempfile.open do |f|
    settings.fbs.load(j.uri1, f.path)
    content_type('application/octet-stream')
    File.binread(f.path)
  end
end
