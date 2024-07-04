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

helpers do
  def ago(time)
    "<span title='#{time.utc.iso8601}'>#{time.ago} ago</span>"
  end

  def zents(num)
    usd = format('%.5f', num.to_f / (1000 * 100))
    num.positive? ? "<span style='color:green'>+#{usd}</span>" : "<span style='color:firebrick'>#{usd}</span>"
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

  def footer_status(title, always)
    a, b, c = always.to_s.split('/').map(&:to_i)
    if c.positive?
      c =
        "<a href='#{iri.cut('/footer/status').add(badge: title)}'>" \
        "<span style='color:firebrick;'>#{c}</span></a>"
    end
    "#{title}:#{a}/#{b}/#{c}"
  end
end
