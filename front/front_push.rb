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
require 'factbase'
require_relative '../objects/baza/urror'
require_relative '../objects/baza/errors'

def user_agent
  agent = request.env['HTTP_USER_AGENT']
  raise Baza::Urror, 'It is mandatory to provide User-Agent HTTP header' if agent.nil?
  raise Baza::Urror, 'The User-Agent HTTP header cannot be empty' if agent.empty?
  agent
end

# @param [Baza::Token] token The token to start at
# @param [File] file The file with a factbase
# @param [String] name The name of the job
# @return [Baza::Job] The job just started
def job_start(token, file, name)
  max_file_size = 10 * 1024 * 1024
  if file.size > max_file_size
    raise Baza::Urror, "The uploaded file exceeds the maximum allowed size of #{max_file_size} bytes"
  end
  fb = Factbase.new
  begin
    fb.import(File.binread(file.path)) # just to check that it's readable
  rescue StandardError => e
    raise Baza::Urror, "Cannot parse the data, try to upload again: #{e.message}"
  end
  fid = settings.fbs.save(file.path)
  token.start(
    name, fid,
    File.size(file.path),
    Baza::Errors.new(file.path).count,
    user_agent
  )
end

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
  name = params[:name]
  raise Baza::Urror, 'The "name" form part is missing' if name.nil?
  raise Baza::Urror, "An existing job named '#{name}' is running now" if token.human.jobs.busy?(name)
  Tempfile.open do |f|
    tfile = params[:factbase]
    if tfile.nil?
      File.binwrite(f.path, Factbase.new.export)
    else
      FileUtils.copy(tfile[:tempfile], f.path)
      File.delete(tfile[:tempfile])
    end
    job = job_start(token, f, name)
    settings.loog.info("New push arrived via HTTP POST, job ID is ##{job.id}")
    flash(iri.cut('/jobs'), "New job ##{job.id} started")
  end
end

put(%r{/push/([a-z0-9-]+)}) do
  the_human.jobs.lock(params[:owner]) unless params[:owner].nil?
  text = request.env['HTTP_X_ZEROCRACY_TOKEN']
  raise Baza::Urror, 'The "X-Zerocracy-Token" HTTP header with a token is missing' if text.nil?
  token = settings.humans.his_token(text)
  name = params['captures'].first
  raise Baza::Urror, "An existing job named '#{name}' is running now" if token.human.jobs.busy?(name)
  Tempfile.open do |f|
    request.body.rewind
    File.binwrite(f, request.body.read)
    job = job_start(token, f, name)
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
  the_human.locks.lock(params[:owner]) unless params[:owner].nil?
  j = the_human.jobs.get(params['captures'].first.to_i)
  r = j.result
  content_type('text/plain')
  r.stdout
end

# The job is finished?
get(%r{/finished/([0-9]+)}) do
  the_human.locks.lock(params[:owner]) unless params[:owner].nil?
  j = the_human.jobs.get(params['captures'].first.to_i)
  content_type('text/plain')
  j.finished? ? 'yes' : 'no'
end

get(%r{/pull/([0-9]+).fb}) do
  the_human.locks.lock(params[:owner]) unless params[:owner].nil?
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
  the_human.locks.lock(params[:owner]) unless params[:owner].nil?
  j = the_human.jobs.get(params['captures'].first.to_i)
  raise Baza::Urror, "The job ##{j.id} is expired" if j.expired?
  Tempfile.open do |f|
    settings.fbs.load(j.uri1, f.path)
    content_type('application/octet-stream')
    File.binread(f.path)
  end
end
