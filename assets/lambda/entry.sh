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

if [ -z "${AWS_LAMBDA_RUNTIME_API}" ]; then
  /usr/local/bin/aws-lambda-rie bundle exec aws_lambda_ric main.go &
else
  bundle exec aws_lambda_ric main.go
fi

curl -v http://localhost:8080/
