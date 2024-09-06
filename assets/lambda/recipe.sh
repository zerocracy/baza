#!/bin/bash
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

set -ex
set -o pipefail

trap 'shutdown' EXIT

cd "$(dirname "$0")"

PATH=$(pwd):$PATH

# If the "aws" file exists right here, it's a testing mode:
if [ ! -e aws ]; then
  AWS_TOKEN=$(curl -X PUT 'http://169.254.169.254/latest/api/token' -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600')
  AWS_JSON=$(curl -H "X-aws-ec2-metadata-token: ${AWS_TOKEN}" http://169.254.169.254/latest/meta-data/iam/security-credentials/baza-release)
  AWS_ACCESS_KEY_ID=$(echo "${AWS_JSON}" | jq -r '.AccessKeyId')
  export AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY=$(echo "${AWS_JSON}" | jq -r '.SecretAccessKey')
  export AWS_SECRET_ACCESS_KEY
  AWS_SESSION_TOKEN=$(echo "${AWS_JSON}" | jq -r '.Token')
  export AWS_SESSION_TOKEN
fi

# Don't delete this line, it is not just a comment, but a placeholder
# for all other file that will be placed here by the Liquid engine. Why
# the line is commented out? In order to fool shellcheck.
# {{ save_files }}

if [ -z "${HOME}" ]; then
  # shellcheck disable=SC2116
  HOME=$(echo ~)
  if [ ! -e "${HOME}" ]; then
    echo "For some reason, there is no HOME directory in the system: '${HOME}'"
    exit 1
  fi
  export HOME
fi

if [ -e "${HOME}/.ssh/id_rsa" ]; then
  echo "The private RSA key already exists, most probably you are testing..."
else
  mkdir -p "${HOME}/.ssh"
  mv id_rsa "${HOME}/.ssh/id_rsa"
  chmod 600 "${HOME}/.ssh/id_rsa"
  ssh-keyscan -t rsa github.com >> "${HOME}/.ssh/known_hosts"
fi

printf '0' > exit.txt

SECONDS=0

/bin/bash "{{ script }}.sh" 2>&1 | tee stdout.log || echo $? > exit.txt

tail -1000 stdout.log > tail.log

if [ ! -e head.txt ] || [ ! -s head.txt ]; then
  printf '0000000000000000000000000000000000000000' > head.txt
fi

curl -s -X PUT --data-binary '@tail.log' -H 'Content-Type: text/plain' \
  "{{ host }}/swarms/finish?secret={{ secret }}&head=$(cat head.txt)&exit=$(cat exit.txt)&sec=${SECONDS}"
