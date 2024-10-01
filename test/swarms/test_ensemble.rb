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
class EnsembleTest < Minitest::Test
  def test_runs_ensemble
    job = fake_job
    s = fake_human.swarms.add(fake_name, "#{fake_name}/#{fake_name}", 'master', '/')
    Dir.mktmpdir do |home|
      save_script(
        home, 'entry.sh',
        "
        #!/bin/bash
        set -ex
        mkdir /tmp/e
        ./pop.sh 0 /tmp/e
        rm -rf /tmp/e/*
        echo '{\"messageAttributes\":{
          \"previous\": {\"stringValue\": \"#{s.name}\"},
          \"more\": {\"stringValue\": \"baza-#{s.name}\"}}}' > /tmp/e/event.json
        ./shift.sh #{job.id} /tmp/e
        rm -rf /tmp/e/*
        echo '{\"messageAttributes\":{
          \"previous\": {\"stringValue\": \"baza-#{s.name}\"}}}' > /tmp/e/event.json
        ./finish.sh #{job.id} /tmp/e
        "
      )
      save_script(
        home, 'aws',
        "
        #!/bin/bash
        set -e
        >&2 echo AWS $@
        if [ \"${1}\" == 's3' ]; then
          if [ \"${2}\" == 'cp' ]; then
            if [ \"${4}\" == 'pack.zip' ]; then
              mkdir archive
              echo '{ \"id\": \"#{job.id}\" }' > archive/job.json
              cp $(dirname $0)/empty.fb archive/base.fb
              mkdir -p archive/swarm-001-42-baza-foo
              echo 'nothing special in the output' > archive/swarm-001-42-baza-foo/stdout.txt
              cd archive && zip -r \"../${4}\" . && cd ..
              rm -rf archive
            fi
          elif [ \"${2}\" == 'sqs' ]; then
            if [ \"${3}\" == 'send-message' ]; then
              echo '{ \"MessageId\": \"c5b90e2f-5177-4fc4-b9b2-819582cc5446\" }'
            fi
          fi
        fi
        "
      )
      FileUtils.copy(File.join(__dir__, '../../swarms/pop/entry.sh'), File.join(home, 'pop.sh'))
      FileUtils.copy(File.join(__dir__, '../../swarms/shift/entry.sh'), File.join(home, 'shift.sh'))
      FileUtils.copy(File.join(__dir__, '../../swarms/finish/entry.sh'), File.join(home, 'finish.sh'))
      File.binwrite(File.join(home, 'empty.fb'), Factbase.new.export)
      save_script(
        home, 'Dockerfile',
        '
        FROM ruby:3.3
        WORKDIR /r
        RUN apt-get update -y && apt-get install -y jq zip unzip curl
        COPY entry.sh pop.sh shift.sh finish.sh aws ./
        RUN chmod a+x entry.sh pop.sh shift.sh finish.sh aws
        COPY empty.fb ./
        ENV PATH=/r:${PATH}
        ENTRYPOINT ["/bin/bash", "entry.sh"]
        '
      )
      img = 'test-ensemble'
      qbash("docker build #{home} -t #{img}", log: fake_loog)
      RandomPort::Pool::SINGLETON.acquire do |port|
        fake_front(port, loog: fake_loog) do
          stdout = qbash(
            [
              'docker run --add-host host.docker.internal:host-gateway ',
              "--user #{Process.uid}:#{Process.gid} ",
              "-e BAZA_URL -e SWARM_ID -e SWARM_SECRET --rm #{img}"
            ].join,
            log: fake_loog,
            env: {
              'BAZA_URL' => "http://host.docker.internal:#{port}",
              'SWARM_ID' => s.id.to_s,
              'SWARM_SECRET' => s.secret
            }
          )
          assert_include(
            stdout,
            'adding: base.fb',
            'adding: swarm-001-42-baza-foo/stdout.txt',
            'AWS s3 rm s3://swarms.zerocracy.com/',
            '--message-attributes'
          )
        ensure
          qbash("docker rmi #{img}", log: fake_loog)
        end
      end
    end
    assert_equal(0, job.result.exit)
    assert(job.result.stdout.include?('nothing special'), job.result.stdout)
  end

  private

  def save_script(dir, file, content)
    sh = File.join(dir, file)
    File.write(sh, content)
    FileUtils.chmod('+x', sh)
  end
end
