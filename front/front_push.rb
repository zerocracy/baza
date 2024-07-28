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
require 'base64'
require 'zlib'
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
# @param [Array<String>] metas List of metas to add
# @return [Baza::Job] The job just started
def job_start(token, file, name, metas)
  max_file_size = 10 * 1024 * 1024
  if file.size > max_file_size
    raise Baza::Urror, "The uploaded file exceeds the maximum allowed size of #{max_file_size} bytes"
  end
  fb = Factbase.new
  begin
    fb.import(File.binread(file.path)) # just to check that it's readable
  rescue StandardError => e
    raise Baza::Urror, "Cannot parse the data, try to upload again: #{e.message.inspect}"
  end
  raise Baza::Urror, "An existing job named '#{name}' is running now" if token.human.jobs.busy?(name)
  fid = settings.fbs.save(file.path)
  token.start(
    name, fid,
    File.size(file.path),
    Baza::Errors.new(file.path).count,
    user_agent,
    (request.env['HTTP_X_ZEROCRACY_META'] || '').split(/\s+/).map { |v| Base64.decode64(v) } + metas
  )
end

# @param [Sinatra::IndifferentHash] uploaded_file The uploaded file data
# @param [File] file The file that accepts the uploaded data
# @param [String] content_encoding The file content encoding
def save_uploaded_file(uploaded_file, file, content_encoding)
  if content_encoding == 'gzip'
    Zlib::GzipReader.open(uploaded_file[:tempfile]) do |gz|
      File.binwrite(file.path, gz.read)
    end
  else
    FileUtils.copy(uploaded_file[:tempfile], file.path)
  end
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
  Tempfile.open do |f|
    tfile = params[:factbase]
    if tfile.nil?
      File.binwrite(f.path, Factbase.new.export)
    else
      save_uploaded_file(tfile, f, request.env['HTTP_CONTENT_ENCODING'])
      File.delete(tfile[:tempfile])
    end
    job = job_start(token, f, name, ['push:post'])
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
  Tempfile.open do |f|
    request.body.rewind
    readable_source = if request.env['HTTP_CONTENT_ENCODING'] == 'gzip' || request.env['HTTP_CONTENT_TYPE'] == 'application/zip'
      Zlib::GzipReader.new(request.body)
    else
      request.body
    end
    File.binwrite(f, readable_source.read)
    job = job_start(token, f, name, ['push:put'])
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
