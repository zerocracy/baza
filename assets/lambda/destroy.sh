#!/bin/bash
# MIT License
#
# Copyright (c) 2009-2025 Zerocracy
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

set -e
set -o pipefail

if aws ecr describe-repositories --repository-names '{{ name }}' --region '{{ region }}' >/dev/null 2>&1; then
  aws ecr delete-repository \
    --repository-name '{{ name }}' \
    --region '{{ region }}' \
    --force \
    --color off >/dev/null
fi

if aws lambda get-function --function-name '{{ name }}' --region '{{ region }}' >/dev/null 2>&1; then
  aws lambda delete-function \
    --function-name '{{ name }}' \
    --region '{{ region }}' \
    --color off >/dev/null
fi

if aws sqs get-queue-url --queue-name '{{ name }}' --region '{{ region }}' >/dev/null 2>&1; then
  aws sqs delete-queue \
    --queue-url 'https://sqs.{{ region }}.amazonaws.com/{{ account }}/{{ name }}' \
    --region '{{ region }}' \
    --color off >/dev/null
  echo "Now, we have to wait a bit, to make sure SQS queue deleted entirely..."
  sleep 60
fi

if aws iam get-role --role-name '{{ name }}' >/dev/null 2>&1; then
  while IFS= read -r policy; do
    aws iam delete-role-policy \
      --role-name '{{ name }}' \
      --policy-name "${policy}" \
      --color off >/dev/null
  done < <( aws iam list-role-policies --role-name '{{ name }}' --output json | jq -r '.PolicyNames[]' )
  aws iam delete-role \
    --role-name '{{ name }}' \
    --color off >/dev/null
fi

if [ "$(aws logs describe-log-groups --log-group-name-pattern '{{ name }}' --region '{{ region }}' 2>&1)" == '{{ name }}' ]; then
  aws logs delete-log-group \
    --log-group-name '{{ name }}' \
    --region '{{ region }}' \
    --color off >/dev/null
fi
