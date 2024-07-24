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

helpers do
  def if_meta(job, name)
    meta = job.metas.find { |m| m.start_with?("#{name}:") }
    if meta.nil?
      ''
    else
      yield meta.split("#{name}:", 2)[1]
    end
  end

  def largetext(text)
    span = "<span style='display:inline-block;'>"
    body = CGI.escapeHTML(text)
      .tr("\n", '↵')
      .split(/(.{4})/)
      .map { |i| i.gsub(' ', "<span class='lightgray'>&#x2423;</span>") }
      .join("</span>#{span}")
      .chars.map { |c| c.ord > 0x7f ? "<span class='firebrick'>\\x#{format('%x', c.ord)}</span>" : c }
      .join
    "#{span}#{body}</span>"
  end

  def ago(time)
    "<span title='#{time.utc.iso8601}'>#{time.ago} ago</span>"
  end

  def usd(num, digits: 4)
    format("%+.#{digits}f", num.to_f / (1000 * 100))
  end

  def zents(num, digits: 4)
    usd = usd(num, digits:)
    color = num.positive? ? 'good' : 'firebrick'
    "<span style='color:#{color}' title='#{usd(num, digits: 6)}'>#{usd}</span>"
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
    if bytes < 1000
      "#{bytes}B"
    elsif bytes < 1000 * 1000
      "#{format('%d', bytes / 1000)}kB"
    else
      "#{format('%d', bytes / (1000 * 1000))}MB"
    end
  end

  def href(link, text, dot: false)
    " <a href='#{link}'>#{text}</a>#{dot ? '.' : ''} "
  end

  def menu(cut, name)
    href = iri.cut(cut)
    if iri.to_s == href.to_s
      "<li>#{name}</li>"
    else
      "<li><a href='#{iri.cut(cut)}'>#{name}</a></li>"
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
end
