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
require_relative '../test__helper'

# Test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class EnsembleTest < Minitest::Test
  def test_runs_ensemble
    loog = fake_loog
    job = fake_job
    s = fake_human.swarms.add(fake_name, "#{fake_name}/#{fake_name}", 'master', '/')
    Dir.mktmpdir do |home|
      save_script(
        home, 'entry.sh',
        "
        #!/bin/bash
        mkdir temp
        ./pop.sh 0 temp
        rm -rf temp/*
        echo '{\"messageAttributes\":{
          \"swarm\": {\"stringValue\": \"#{s.name}\"},
          \"more\": {\"stringValue\": \"#{s.name}\"}}}' > temp/event.json
        ./shift.sh #{job.id} temp
        rm -rf temp/*
        echo '{\"messageAttributes\":{
          \"swarm\": {\"stringValue\": \"#{s.name}\"}}}' > temp/event.json
        ./finish.sh #{job.id} temp
        "
      )
      save_script(
        home, 'aws',
        "
        #!/bin/bash
        set -ex
        if [ \"${1}\" == 's3' ]; then
          if [ \"${2}\" == 'cp' ]; then
            if [ \"${4}\" == 'pack.zip' ]; then
              mkdir archive
              echo '{ \"id\": \"#{job.id}\", \"exit\": 0, \"msec\": 500 }' > archive/job.json
              cp $(dirname $0)/empty.fb archive/base.fb
              echo 'nothing special in the output' > archive/stdout.txt
              zip -j \"${4}\" archive/*
              rm -rf archive
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
        COPY entry.sh pop.sh shift.sh finish.sh aws .
        RUN chmod a+x entry.sh pop.sh shift.sh finish.sh aws
        COPY empty.fb .
        ENV PATH=/r:${PATH}
        ENTRYPOINT ["/bin/bash", "entry.sh"]
        '
      )
      img = 'test-ensemble'
      bash("docker build #{home} -t #{img}", loog)
      RandomPort::Pool::SINGLETON.acquire do |port|
        fake_front(port, loog) do
          stdout = bash(
            [
              'docker run --add-host host.docker.internal:host-gateway ',
              "-e BAZA_URL -e SWARM_ID -e SWARM_SECRET --rm #{img}"
            ].join,
            loog,
            'BAZA_URL' => "http://host.docker.internal:#{port}",
            'SWARM_ID' => s.id.to_s,
            'SWARM_SECRET' => s.secret
          )
          [
            'adding: base.fb',
            'adding: stdout.txt',
            'aws s3 rm s3://swarms.zerocracy.com/',
            '--message-attributes'
          ].each { |t| assert(stdout.include?(t), "Can't find #{t.inspect} in\n#{stdout}") }
        ensure
          bash("docker rmi #{img}", loog)
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
