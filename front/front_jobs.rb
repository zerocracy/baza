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

require 'judges/commands/print'

get '/jobs' do
  assemble(
    :jobs,
    :default,
    title: '/jobs',
    jobs: the_human.jobs,
    name: params[:name],
    offset: (params[:offset] || '0').to_i
  )
end

get(%r{/jobs/([0-9]+)}) do
  id = params['captures'].first.to_i
  assemble(
    :job,
    :default,
    title: "/jobs/#{id}",
    job: the_human.jobs.get(id)
  )
end

get(%r{/jobs/([0-9]+)/expire}) do
  id = params['captures'].first.to_i
  job = the_human.jobs.get(id)
  job.expire!(settings.fbs, 'By request of the user')
  flash(iri.cut('/jobs').append(id), "The job ##{job.id} expired, all data removed")
end

def render_html(uri, name)
  Dir.mktmpdir do |d|
    fb = File.join(d, "#{name}.fb")
    html = File.join(d, "#{name}.html")
    settings.fbs.load(uri, fb)
    Judges::Print.new(settings.loog).run(
      {
        'title' => name,
        'format' => 'html',
        'columns' => 'what,when,who,repository,issue,details',
        'hide' => '_id,_time,_version,where'
      },
      [fb, html]
    )
    content_type('text/html')
    File.binread(html)
  end
end

get(%r{/jobs/([0-9]+)/input.html}) do
  id = params['captures'].first.to_i
  job = the_human.jobs.get(id)
  render_html(job.uri1, job.id)
end

get(%r{/jobs/([0-9]+)/output.html}) do
  id = params['captures'].first.to_i
  job = the_human.jobs.get(id)
  render_html(job.result.uri2, job.result.id)
end

get(%r{/jobs/([0-9]+)/verified.txt}) do
  id = params['captures'].first.to_i
  job = the_human.jobs.get(id)
  content_type('text/plain')
  job.verified || ''
end
