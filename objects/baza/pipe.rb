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

require 'zip'

# Pipe of jobs.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Pipe
  def initialize(humans, fbs)
    @humans = humans
    @fbs = fbs
  end

  def pop(owner)
    rows = @humans.pgsql.exec(
      [
        'UPDATE job SET taken = $1 WHERE id = (',
        '  SELECT job.id FROM job',
        '  LEFT JOIN result ON result.job = job.id',
        '  WHERE result.id IS NULL AND taken IS NULL',
        '  LIMIT 1)',
        'RETURNING id'
      ],
      [owner]
    )
    return nil if rows.empty?
    @humans.job_by_id(rows.first['id'].to_i)
  end

  # Pack one job into a ZIP file.
  #
  # @param [Baza::Job] job The job to pack
  # @param [String] file The path to .zip file to create
  def pack(job, file)
    Dir.mktmpdir do |dir|
      Zip::File.open(file, create: true) do |zip|
        fb = File.join(dir, "#{job.id}.fb")
        @fbs.load(job.uri1, fb)
        zip.add(fb, fb)
        alts = job.jobs.human.alterations
        idx = 0
        alts.each(pending: true) do |a|
          next if a[:name] != job.name
          af = File.join(dir, "alternation-#{a[:id]}.rb")
          File.write(af, a[:script])
          zip.add(af)
        end
      end
    end
  end

  # Unpack a ZIP file and finish the job with the information from it.
  #
  # @param [Baza::Job] job The job to pack
  # @param [String] file The path to .zip file to read
  def unpack(job, file)
    Dir.mktmpdir do |dir|
      Zip::File.open(file) do |zip|
        zip.each do |entry|
          entry.extract(File.join(dir, entry.name))
        end
      end
    end
  end
end
