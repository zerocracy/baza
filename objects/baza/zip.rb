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

require 'loog'
require 'zip'
require 'fileutils'
require 'pathname'

# Zip archive.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Zip
  # Ctor.
  #
  # @param [String] file The path of .zip archive
  # @param [Loog] loog The log
  def initialize(file, loog: Loog::NULL)
    @file = file
    @loog = loog
  end

  def entries
    list = []
    Zip::File.open(@file) do |zip|
      zip.each do |entry|
        list << entry.name
      end
    end
    list
  end

  # Pack all files in the directory into the ZIP archive.
  #
  # @param [String] dir The path of the directory
  def pack(dir)
    FileUtils.rm_f(@file)
    entries = []
    Zip::File.open(@file, create: true) do |zip|
      Dir.glob(File.join(dir, '**/*'), File::FNM_DOTMATCH).each do |f|
        next if f == @file
        path = Pathname.new(f).relative_path_from(dir)
        next if path.to_s == '.'
        zip.add(path, f)
        entries << "#{path}#{File.directory?(f) ? '/' : ": #{File.size(f)}"}"
      end
    end
    @loog.debug("Directory #{dir} zipped to #{@file} (#{File.size(@file)} bytes):\n#{entries.join("\n")}")
  end

  # Unpack a ZIP file into the directory.
  #
  # @param [String] dir The path to directory
  def unpack(dir)
    entries = []
    FileUtils.mkdir_p(dir)
    Zip::File.open(@file) do |zip|
      zip.each do |entry|
        t = File.join(dir, entry.name)
        next if t == @file
        entry.extract(t)
        entries << "#{t}: #{File.size(t)}"
      end
    end
    @loog.debug("The archive #{@file} (#{File.size(@file)} bytes) unzipped to #{dir}:\n#{entries.join("\n")}")
  end
end
