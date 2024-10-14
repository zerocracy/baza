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

get '/valves' do
  assemble(
    :valves,
    :default,
    title: '/valves',
    valves: the_human.valves,
    offset: (params[:offset] || '0').to_i
  )
end

def as_result(text)
  return text.to_f if text =~ /^[0-9]+\.[0-9]+$/
  return text.to_i if text =~ /^[0-9]+$/
  return nil if text == 'NIL'
  text
end

post('/valves/add') do
  badge = params[:badge]
  raise Baza::Urror, "The valve #{badge.inspect} already exists" if the_human.valves.exists?(badge)
  the_human.valves.enter(params[:name], badge, params[:why], nil) { as_result(params[:result]) }
  flash(iri.cut('/valves'), "The valve '#{params[:badge]}' has been added for '#{params[:name]}'")
end

get('/valves/result') do
  badge = params[:badge]
  v = the_human.valves.find(badge)
  return [204, "Valve #{badge.inspect} not found"] if v.nil?
  v.result.to_s
end

get(%r{/valves/([0-9]+)}) do
  id = params['captures'].first.to_i
  assemble(
    :valve,
    :default,
    title: "/valves/#{id}",
    valve: the_human.valves.get(id),
    css: 'valve'
  )
end

get(%r{/valves/([0-9]+)/remove}) do
  id = params['captures'].first.to_i
  the_human.valves.remove(id)
  flash(iri.cut('/valves'), "The valve ##{id} just removed")
end

get '/reset' do
  assemble(:reset, :default, title: '/reset')
end

post('/valves/reset') do
  id = params[:id].to_i
  the_human.valves.reset(id, as_result(params[:result]))
  flash(iri.cut('/valves'), "The valve ##{id} reset")
end
