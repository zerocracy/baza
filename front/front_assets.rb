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

require 'redcarpet'
require 'open-uri'

get %r{/svg/([a-z0-9-]+.svg)} do
  n = params['captures'].first
  content_type 'image/svg+xml'
  file = File.join(File.absolute_path('./assets/svg/'), n)
  error 404 unless File.exist?(file)
  File.read(file)
end

get %r{/png/([a-z0-9-]+.png)} do
  n = params['captures'].first
  content_type 'image/png'
  file = File.join(File.absolute_path('./assets/png/'), n)
  error 404 unless File.exist?(file)
  File.read(file)
end

get %r{/css/([a-z0-9-]+).css} do
  content_type 'text/css', charset: 'utf-8'
  n = params['captures'].first
  template = File.join(File.absolute_path('./assets/scss/'), "#{n}.scss")
  error 404 unless File.exist?(template)
  require 'sass-embedded'
  Sass.compile(template, style: :compressed).css
end

get(%r{/(terms)}) do
  n = params['captures'].first
  f = File.join(File.absolute_path('./assets/markdown/'), "#{n}.md")
  html = Redcarpet::Markdown.new(Redcarpet::Render::HTML).render(File.read(f))
  assemble(
    :markdown,
    :empty,
    title: "/#{n}",
    html:
  )
end

get(%r{/flag-of/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})}) do
  ip = params['captures'].first
  content_type 'image/png'
  src =
    settings.zache.get("flag-of-#{ip}") do
      settings.ipgeolocation.ipgeo(ip:)['country_flag']
    end
  URI.parse(src).open.read if src
end
