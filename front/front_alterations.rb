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

get '/alterations' do
  admin_only
  flash(iri.cut('/dash'), 'You have no jobs yet, nothing to alter') if the_human.jobs.empty?
  assemble(
    :alterations,
    :default,
    title: '/alterations',
    alterations: the_human.alterations,
    css: 'alterations',
    offset: (params[:offset] || '0').to_i
  )
end

get(%r{/alterations/([0-9]+)/remove}) do
  admin_only
  id = params['captures'].first.to_i
  the_human.alterations.remove(id)
  flash(iri.cut('/alterations'), "The alteration ##{id} just removed")
end

get(%r{/alterations/([0-9]+)/copy}) do
  admin_only
  id = params['captures'].first.to_i
  a = the_human.alterations.get(id)
  id = the_human.alterations.add(a[:name], 'ruby', { script: a[:script] })
  flash(iri.cut('/alterations'), "The alteration ##{a[:id]} just copied to #{id}")
end

post('/alterations/add') do
  admin_only
  n = params[:name]
  t = params[:template]
  id = the_human.alterations.add(n, t, params)
  flash(iri.cut('/alterations'), "The alteration ##{id} ('#{t}') just added for '#{n}'")
end
