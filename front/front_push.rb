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

get '/push' do
  assemble(
    :push,
    :default,
    title: '/push',
    token: the_human.tokens.size == 1 ? the_human.tokens.to_a[0].text : ''
  )
end

post '/push' do
  token = the_human.tokens.find(params[:token])
  raise Baza::Urror, 'The token is inactive' unless token.active?
  Tempfile.open do |f|
    FileUtils.copy(params[:factbase][:tempfile], f.path)
    File.delete(params[:factbase][:tempfile])
    fid = settings.factbases.save(f.path)
    job = token.start(fid)
    response.headers['X-Zerocracy-JobId'] = job.id.to_s
    flash(iri.cut('/jobs'), "New job ##{job.id} started")
  end
end
