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

require 'minitest/autorun'
require 'random-port'
require 'qbash'
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class FinishTest < Minitest::Test
  def test_runs_finish_entry_script
    job = fake_job
    s = fake_human.swarms.add(fake_name, "#{fake_name}/#{fake_name}", 'master', '/')
    Dir.mktmpdir do |home|
      %w[aws].each do |f|
        sh = File.join(home, f)
        File.write(
          sh,
          "
          #!/bin/bash
          set -ex
          if [ \"${1}\" == 's3' ]; then
            if [ \"${2}\" == 'cp' ]; then
              rm -rf pack
              mkdir pack
              echo '{ \"id\": \"#{job.id}\", \"exit\": 0, \"msec\": 500 }' > pack/job.json
              cp $(dirname $0)/empty.fb pack/base.fb
              echo '' > pack/stdout.txt
              cd pack && zip -r ../$4 . && cd ..
            fi
          fi
          "
        )
        FileUtils.chmod('+x', sh)
      end
      FileUtils.copy(File.join(__dir__, '../../swarms/finish/entry.sh'), home)
      File.binwrite(File.join(home, 'empty.fb'), Factbase.new.export)
      File.write(
        File.join(home, 'event.json'),
        JSON.pretty_generate(
          {
            messageAttributes: {
              swarm: { stringValue: s.name },
              hops: { stringValue: '5' }
            }
          }
        )
      )
      File.write(
        File.join(home, 'Dockerfile'),
        "
        FROM ruby:3.3
        WORKDIR /r
        RUN apt-get update -y && apt-get install -y jq zip unzip curl
        COPY entry.sh aws empty.fb ./
        RUN chmod a+x aws
        RUN mkdir -p /tmp/work
        COPY event.json /tmp/work
        RUN chown -R #{Process.uid}:#{Process.gid} /tmp/work
        ENV PATH=/r:${PATH}
        ENTRYPOINT [\"/bin/bash\", \"entry.sh\"]
        "
      )
      fake_image(home) do |image|
        RandomPort::Pool::SINGLETON.acquire do |port|
          fake_front(port, loog: fake_loog) do
            fake_container(
              image, '', "#{job.id} /tmp/work",
              env: {
                'BAZA_URL' => "http://#{fake_docker_host}:#{port}",
                'MESSAGE_ID' => 'b94df65a-97f2-4566-876a-576e1fc1890e',
                'SWARM_ID' => s.id.to_s,
                'SWARM_SECRET' => s.secret
              }
            )
          end
        end
      end
    end
  end
end
