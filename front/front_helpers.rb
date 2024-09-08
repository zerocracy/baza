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

require 'tago'
require 'cgi'
require 'securerandom'
require_relative '../objects/baza/ipgeolocation'

# Front helpers.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
module Baza::Helpers
  def paging(items, params = {}, &)
    total = 0
    max = 10
    items.each(**params) do |v|
      total += 1
      break if total > max
      yield v
    end
    @_out_buf << html_tag('tr') do
      html_tag('td', colspan: '4') do
        html_tag('nav') do
          html_tag('ul', style: 'margin-bottom: 0; text-align: left;') do
            [
              params[:offset].zero? ? '' : html_tag('li') do
                html_tag('a', href: iri.del(:offset)) do
                  [
                    html_tag('i', class: 'fa-solid fa-backward'),
                    html_tag('span', style: 'margin-left: .5em') { 'Back' }
                  ].join
                end
              end,
              total > max ? html_tag('li') do
                html_tag('a', href: iri.over(offset: params[:offset] + max)) do
                  [
                    html_tag('span', style: 'margin-right: .5em') { 'More' },
                    html_tag('i', class: 'fa-solid fa-forward')
                  ].join
                end
              end : ''
            ].join
          end
        end
      end
    end
  end

  def escape(txt)
    CGI.escape(txt).gsub('+', '%20')
  end

  def html_tag(tag, attrs = {})
    html = block_given? ? yield : ''
    a = attrs.map { |k, v| "#{k}=\"#{CGI.escapeHTML(v.to_s)}\"" }.join(' ')
    "<#{tag}#{a.empty? ? '' : " #{a}"}>#{html}</#{tag}>"
  end

  def secret(txt, eye: true)
    body =
      if txt.size > 20
        [
          html_tag('span') { txt[0..4] },
          html_tag('span', class: 'gray') { "***#{txt.size - 14}***" },
          html_tag('span') { txt[-5..] }
        ].join
      elsif txt.size < 5
        html_tag('span', class: 'gray') { ('*' * txt.size).to_s }
      else
        [
          html_tag('span') { txt[0..3] },
          html_tag('span', class: 'gray') { ('*' * (txt.size - 4)).to_s }
        ].join
      end
    return body unless eye
    uuid = SecureRandom.uuid
    js_eye = [
      "$('##{CGI.escapeHTML(uuid)} .full').html(decodeURIComponent('#{escape(large_text(txt))}'));",
      "$('##{uuid} a.eye').hide();",
      "$('##{uuid} a.copy').show();",
      'return false;'
    ].join
    js_copy = [
      "navigator.clipboard.writeText(decodeURIComponent('#{escape(txt)}'));",
      '$(this).next().show().delay(1000).fadeOut();',
      'return false;'
    ].join
    html_tag('span', id: uuid) do
      [
        html_tag('span', class: 'full') { body },
        html_tag(
          'a',
          href: '',
          title: 'Show the secret',
          class: 'eye',
          onclick: js_eye
        ) { html_tag('i', class: 'fa-regular fa-eye') },
        html_tag(
          'a',
          href: '',
          title: 'Copy the secret',
          class: 'copy',
          style: 'display: none',
          onclick: js_copy
        ) { html_tag('i', class: 'fa-regular fa-copy') },
        html_tag('span', class: 'gray', style: 'display: none;') { 'Copied to clipboard!' }
      ].join('&nbsp;')
    end
  end

  def succeed(txt)
    r = yield
    "#{r}#{txt} "
  end

  def if_meta(job, name)
    meta = job.metas.find { |m| m.start_with?("#{name}:") }
    if meta.nil?
      ''
    else
      yield meta.split("#{name}:", 2)[1]
    end
  end

  def large_text(text)
    return "#{text}<sub class='gray'>i</sub>" if text.is_a?(Integer)
    return "#{text}<sub class='gray'>f</sub>" if text.is_a?(Float)
    return '<i class="gray">nil</i>' if text.nil?
    return "#{text.class}<sub class='gray'>c</sub>" unless text.is_a?(String)
    html = text
      .tr("\n", '↵')
      .scan(/.{1,4}/)
      .map do |t|
        html_tag('span', style: 'display:inline-block;') do
          CGI.escapeHTML(t).gsub(' ', html_tag('span', class: 'lightgray') { '&#x2423;' })
        end
      end
      .join
      .chars
      .map { |c| c.ord > 0x7f ? "<span class='firebrick'>\\x#{format('%x', c.ord)}</span>" : c }
      .join
    "<span class='gray'>\"</span>#{html}<span class='gray'>\"</span>"
  end

  def ago(time)
    html_tag('span', title: time.utc.iso8601) { "#{time.ago} ago" }
  end

  def usd(num, digits: 4)
    format("%+.#{digits}f", num.to_f / (1000 * 100))
  end

  def zents(num, digits: 4)
    usd = usd(num, digits:)
    html_tag(
      'span',
      class: num.positive? ? 'good' : 'bad',
      title: usd(num, digits: 6)
    ) { usd }
  end

  def msec(msec)
    if msec < 1000
      "#{msec}㎳"
    elsif msec < 60 * 1000
      "#{msec / 1000}s"
    else
      format('%.1fm', msec / (1000 * 60))
    end
  end

  def bytes(bytes)
    html_tag('span', title: "#{bytes.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} bytes") do
      if bytes < 1000
        "#{bytes}B"
      elsif bytes < 1000 * 1000
        "#{format('%d', bytes / 1000)}kB"
      else
        "#{format('%d', bytes / (1000 * 1000))}MB"
      end
    end
  end

  def href(link, text, dot: false)
    " <a href='#{link}'>#{text}</a>#{dot ? '.' : ''} "
  end

  def menu(cut, name)
    href = iri.cut(cut)
    if iri.to_s == href.to_s
      html_tag('li') { name }
    else
      html_tag('li') { html_tag('a', href: iri.cut(cut).to_s) { name } }
    end
  end

  def footer_status(title)
    always = settings.send(title)
    s = always.to_s
    a, b, c = s.split('/').map(&:to_i)
    return "#{title}:#{s[0..40].inspect}" if c.nil?
    if c.positive?
      c =
        "<a href='#{iri.cut('/footer/status').add(badge: title)}'>" \
        "<span style='color:firebrick;'>#{c}</span></a>"
    end
    "#{title}:#{a}/#{b}/#{c}"
  end

  def telegram?
    id = the_human.id
    settings.telegramers[id] = the_human.telegram? if settings.telegramers[id].nil?
    settings.telegramers[id]
  end

  def country_flag(ip)
    html_tag('img', style: 'width: 1em', src: "/flag-of/#{ip}")
  end

  def snippet(text, preview: false, unrollable: true)
    lines = text.split("\n")
    [
      unrollable ? html_tag(
        'i',
        class: 'fa-regular fa-eye',
        onclick:
          '
          $(this).hide();
          $(this).parent().find("span").hide();
          $(this).parent().find("pre").show();
          ',
        style: 'cursor: pointer; margin-right: .5em;',
        title: 'Click here to see the full snippet'
      ) : '',
      html_tag('span') { preview ? lines.first : "#{lines.count} lines" },
      unrollable ? html_tag('pre', style: 'display: none;') { text } : ''
    ].join
  end
end

helpers do
  include Baza::Helpers
end
