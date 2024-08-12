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
    durables: the_durables
  )
end

put(%r{/durables/([0-9]+)}) do
  id = params['captures'].first.to_i
  Tempfile.open do |f|
    request.body.rewind
    File.binwrite(f, request.body.read)
    the_durables.get(id).save(f.path)
  end
end

get(%r{/durables/([0-9]+)}) do
  id = params['captures'].first.to_i
  Tempfile.open do |f|
    d = the_durables.get(id)
    d.load(f.path)
    content_type('application/octet-stream')
    response.headers['Content-Disposition'] = "attachment; filename=\"#{d.file}\""
    File.binread(f.path)
  end
end

post(%r{/durables/place}) do
  jname = params[:jname]
  raise Baza::Urror, 'The "jname" param is mandatory' if jname.nil?
  file = params[:file]
  raise Baza::Urror, 'The "file" param is mandatory' if file.nil?
  zip = params[:zip]
  raise Baza::Urror, 'The "zip" param is mandatory (with file content)' if zip.nil?
  durable =
    Tempfile.open do |f|
      FileUtils.copy(zip[:tempfile], f.path)
      the_durables.place(jname, file, f.path)
    end
  response.headers['X-Zerocracy-DurableId'] = durable.id.to_s
  flash(iri.cut('/durables'), "The ID of the durable is ##{durable.id}")
end

get(%r{/durables/([0-9]+)/lock}) do
  id = params['captures'].first.to_i
  owner = params[:owner]
  raise Baza::Urror, 'The "owner" param is mandatory' if owner.nil?
  the_durables.get(id).lock(owner)
  flash(iri.cut('/durables'), "The durable ##{id} locked")
end

get(%r{/durables/([0-9]+)/unlock}) do
  id = params['captures'].first.to_i
  owner = params[:owner]
  raise Baza::Urror, 'The "owner" param is mandatory' if owner.nil?
  the_durables.get(id).unlock(owner)
  flash(iri.cut('/durables'), "The durable ##{id} unlocked")
end

get(%r{/durables/([0-9]+)/remove}) do
  id = params['captures'].first.to_i
  the_durables.get(id).delete
  flash(iri.cut('/durables'), "The durable ##{id} was deleted")
end
