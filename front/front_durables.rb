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

def the_durables
  the_human.durables(settings.fbs)
end

get '/durables' do
  assemble(
    :durables,
    :default,
    title: '/durables',
    secrets: the_durables
  )
end

put(%r{/durables/([0-9]+)}) do
  id = params['captures'].first.to_i
  Tempfile.open do |f|
    request.body.rewind
    File.binwrite(f, request.body.read)
    the_durables.save(id, f.path)
  end
end

get(%r{/durables/([0-9]+)}) do
  id = params['captures'].first.to_i
  Tempfile.open do |f|
    the_durables.load(id, f.path)
    content_type('application/octet-stream')
    File.binread(f.path)
  end
end

post(%r{/durables/place}) do
  jname = params[:jname]
  directory = params[:jname]
  id =
    Tempfile.open do |f|
      FileUtils.copy(params[:zip][:tempfile], f.path)
      the_durables.place(jname, directory, f.path)
    end
  response.headers['X-Zerocracy-DurableId'] = id.to_s
  flash(iri.cut('/durables'), "The ID of the durable is ##{id}")
end

get(%r{/durables/([0-9]+)/lock}) do
  id = params['captures'].first.to_i
  owner = params[:owner]
  raise Baza::Urror, 'The "owner" param is mandatory' if owner.nil?
  the_durables.lock(id, owner)
  flash(iri.cut('/durables'), "The durable ##{id} locked")
end

get(%r{/durables/([0-9]+)/unlock}) do
  id = params['captures'].first.to_i
  owner = params[:owner]
  raise Baza::Urror, 'The "owner" param is mandatory' if owner.nil?
  the_durables.unlock(id, owner)
  flash(iri.cut('/durables'), "The durable ##{id} unlocked")
end
