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
class ShiftTest < Baza::Test
  def test_runs_shift_entry_script
    job = fake_job
    s = fake_human.swarms.add(fake_name, "#{fake_name}/#{fake_name}", 'master', '/')
    stdout =
      Dir.mktmpdir do |home|
        %w[aws].each do |f|
          sh = File.join(home, f)
          File.write(
            sh,
            "
            #!/bin/bash
            set -e
            >&2 echo AWS $@
            if [ \"${1}\" == 's3' ]; then
              if [ \"${2}\" == 'sqs' ]; then
                if [ \"${3}\" == 'send-message' ]; then
                  echo '{ \"MessageId\": \"c5b90e2f-5177-4fc4-b9b2-819582cc5446\" }'
                fi
              fi
            fi
            "
          )
          FileUtils.chmod('+x', sh)
        end
        FileUtils.copy(File.join(__dir__, '../../swarms/shift/entry.sh'), home)
        name = "baza-#{s.name}"
        File.write(
          File.join(home, 'event.json'),
          JSON.pretty_generate(
            {
              messageId: 'b94df65a-97f2-4566-876a-576e1fc1890e',
              messageAttributes: {
                previous: { stringValue: name },
                hops: { stringValue: '5' },
                more: { stringValue: 'baza-foo baza-bar baza-xyz' }
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
          COPY entry.sh aws ./
          RUN chmod a+x aws
          RUN mkdir -p /tmp/work
          COPY event.json /tmp/work
          RUN chown -R #{Process.uid}:#{Process.gid} /tmp/work
          ENV PATH=/r:${PATH}
          ENTRYPOINT [\"/bin/bash\", \"entry.sh\"]
          "
        )
        fake_image(home) do |image|
          fake_container(
            image,
            '', "#{job.id} /tmp/work",
            env: {
              'MESSAGE_ID' => 'b94df65a-97f2-4566-876a-576e1fc1890e'
            }
          )
        end
      end
    assert_include(
      stdout,
      "StringValue='#{job.id}'",
      "StringValue='baza-#{s.name}'",
      "StringValue='baza-bar baza-xyz'"
    )
  end
end
