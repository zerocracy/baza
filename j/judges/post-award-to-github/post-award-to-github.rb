# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2024 Zerocracy
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

require 'fbe/octo'
require 'fbe/conclude'

Fbe.conclude do
  on '(and
    (eq where "github")
    (exists who)
    (exists when)
    (exists award)
    (exists why)
    (exists greeting)
    (exists issue)
    (exists repository)
    (not (exists href)))'
  consider do |f|
    name = Fbe.octo.user_name_by_id(f.who)
    repo = Fbe.octo.repo_name_by_id(f.repository)
    id = $valve.enter("announce-reward-#{f.where}-#{f.repository}-#{f.issue}-#{f.who}") do
      okit.add_comment(repo, f.issue, "@#{name} #{f.greeting}")[:id]
    end
    f.href = "https://github.com/#{repo}/issues/#{f.issue}/#issuecomment-#{id}"
    $loog.info("Comment ##{id} posted with an award (#{f.award}) to #{f.href}")
  end
end
