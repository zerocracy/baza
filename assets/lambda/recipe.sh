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
  AWS_JSON=$(curl -H "X-aws-ec2-metadata-token: ${TOKEN}" http://169.254.169.254/latest/meta-data/iam/security-credentials/baza-release)
  export AWS_ACCESS_KEY_ID=$(echo $AWS_JSON | jq -r '.AccessKeyId')
  export AWS_SECRET_ACCESS_KEY=$(echo $AWS_JSON | jq -r '.SecretAccessKey')
  export AWS_SESSION_TOKEN=$(echo $AWS_JSON | jq -r '.Token')
fi

{{ save_files }}

printf '0000000000000000000000000000000000000000' > head.txt
printf '0' > exit.txt

SECONDS=0

(
  mkdir .ssh
  mv id_rsa .ssh/id_rsa
  chmod 600 .ssh/id_rsa

  uri="git@github.com:{{ github }}.git"
  if [ ! -s ~/.ssh/id_rsa ]; then
    uri="https://github.com/{{ github }}"
  fi
  git clone -b "{{ branch }}" --depth=1 --single-branch "${uri}" swarm
  git --git-dir swarm/.git rev-parse HEAD | tr '[:lower:]' '[:upper:]' > head.txt

  aws ecr get-login-password --region "{{ region }}" | docker login --username AWS --password-stdin "{{ repository }}"

  docker build . -t baza --platform linux/amd64

  docker tag baza "{{ repository }}/{{ image }}"
  docker push "{{ repository }}/{{ image }}"

  func="baza-{{ name }}"
  if aws lambda get-function --function-name "${func}" --region "{{ region }}"; then
    aws lambda update-function-code --function-name "${func}" \
      --region "{{ region }}" \
      --image-uri "{{ repository }}/{{ image }}" \
      --publish
  else
    role=arn:aws:iam::{{ account }}:role/baza-lambda
    aws lambda create-function --function-name "${func}" \
      --region "{{ region }}" \
      --package-type Image \
      --code "ImageUri=${uri}" \
      --role "${role}"
    # swarms--use1-az4--x-s3
    # give this function permissions to work with S3 bucket
  fi
) 2>&1 | tail -200 > stdout.log || echo $? > exit.txt

curl -X PUT --data-binary '@stdout.log' -H 'Content-Type: text/plain' \
  "{{ host }}/swarms/finish?secret={{ secret }}&head=$(cat head.txt)&exit=$(cat exit.txt)&sec=${SECONDS}"
