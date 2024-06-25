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

get '/locks' do
  assemble(
    :locks,
    :default,
    title: '/locks',
    locks: the_human.locks
  )
end

# Lock the name of the job.
get(%r{/lock/([a-z0-9-]+)}) do
  n = params['captures'].first
  owner = params[:owner]
  raise Baza::Urror, 'The "owner" is a mandatory query param' if owner.nil?
  raise Baza::Urror, 'The "owner" can\'t be empty' if owner.empty?
  the_human.locks.lock(n, owner)
  flash(iri.cut('/locks'), "The name '#{n}' just locked for '#{owner}'")
end

# Unlock the name of the job.
get(%r{/unlock/([a-z0-9-]+)}) do
  n = params['captures'].first
  owner = params[:owner]
  raise Baza::Urror, 'The "owner" is a mandatory query param' if owner.nil?
  raise Baza::Urror, 'The "owner" can\'t be empty' if owner.empty?
  the_human.locks.lock(n, owner)
  flash(iri.cut('/locks'), "The name '#{n}' just unlocked for '#{owner}'")
end
