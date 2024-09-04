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

uri="git@github.com:{{ github }}.git"
if [ ! -s "${HOME}/.ssh/id_rsa" ]; then
  uri="https://github.com/{{ github }}"
fi

ls -al "${HOME}/.ssh"

GIT_SSH_COMMAND="ssh -v" git clone -b "{{ branch }}" --depth=1 --single-branch "${uri}" swarm
git --git-dir swarm/.git rev-parse HEAD | tr '[:lower:]' '[:upper:]' > head.txt

aws ecr get-login-password --region "{{ region }}" | docker login --username AWS --password-stdin "{{ repository }}"

docker build . -t baza --platform linux/amd64

if ! aws ecr get-repository-policy --repository-name "{{ repository }}/{{ image }}"; then
  aws ecr create-repository --repository-name "{{ repository }}/{{ image }}" --image-tag-mutability MUTABLE
fi

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
    --code "ImageUri={{ repository }}/{{ image }}" \
    --role "${role}"
  # swarms--use1-az4--x-s3
  # give this function permissions to work with S3 bucket
fi
