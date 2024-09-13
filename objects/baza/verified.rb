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

require 'octokit'
require 'base64'

# A verified status of a job.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Verified
  def initialize(job, ipgeolocation, zache)
    @job = job
    @ipgeolocation = ipgeolocation
    @zache = zache
  end

  # Get the verdict.
  def verdict
    return "FAKE: IP #{@job.ip} is not from Microsoft." unless ip_from_microsoft?(@job.ip)
    meta = @job.metas.find { |m| m.start_with?('workflow_url:') }
    return 'FAKE: There is no workflow_url meta' if meta.nil?
    url = meta.split(':', 2)[1]
    mtc = url.match(%r{^https://github\.com/(?<org>[^/]+)/(?<repo>[^/]+)/actions/runs/(?<id>[0-9]+)$})
    return "FAKE: Wrong URL at workflow_url: #{url.inspect}." unless mtc
    octo = Octokit::Client.new
    repo = "#{mtc[:org]}/#{mtc[:repo]}"
    json =
      begin
        octo.workflow_run(repo, mtc[:id].to_i)
      rescue Octokit::NotFound => e
        raise "Workflow URL #{url} not found: #{e.message}."
      end
    path = json[:path].split('@')[0]
    branch = json[:head_branch]
    content =
      begin
        octo.contents(repo, path:, query: { ref: branch })[:content]
      rescue Octokit::NotFound => e
        raise "Workflow content not found at #{repo}/#{path}@#{branch}: #{e.message}."
      end
    content = Base64.decode64(content)
    yaml = YAML.load(content)
    steps = yaml.dig('jobs', 'zerocracy', 'steps')
    return 'FAKE: Can\'t find "jobs/zerocracy/steps".' if steps.nil?
    return 'FAKE: No array in "jobs/zerocracy/steps".' unless steps.is_a?(Array)
    return 'FAKE: Not enough steps in "jobs/zerocracy/steps".' if steps[1].nil?
    n = steps[1]['uses']
    return 'FAKE: No "uses" in the second step.' if n.nil?
    return "FAKE: Wrong 'uses' #{n.inspect} in the second step." unless n.start_with?('zerocracy/judges-action@')
    "OK: All good in https://github.com/#{repo}/blob/#{branch}/#{path}"
  rescue StandardError => e
    "FAKE: #{e.message}"
  end

  private

  def ip_from_microsoft?(ip)
    organization =
      @zache.get("owner-of-#{ip}") do
        @ipgeolocation.ipgeo(ip:)['organization']
      end
    organization.match?(/Microsoft/i)
  end
end
