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

# if aws ecr describe-repositories --repository-names "{{ name }}"; then
#   aws ecr delete-repository \
#     --repository-name "{{ name }}" \
#     --force \
#     --color off
# fi

if aws lambda get-function --function-name "{{ name }}" --region "{{ region }}"; then
  aws lambda delete-function \
    --function-name "{{ name }}" \
    --region "{{ region }}" \
    --color off
fi

if aws sqs get-queue-url --queue-name "{{ name }}" --region "{{ region }}"; then
  aws sqs delete-queue \
    --queue-url "https://sqs.{{ region }}.amazonaws.com/{{ account }}/{{ name }}" \
    --region "{{ region }}" \
    --color off
  echo "Now, we have to wait a bit, to make sure SQS queue deleted entirely..."
  sleep 60
fi

if aws iam get-role --role-name "{{ name }}"; then
  while IFS= read -r policy; do
    aws iam delete-role-policy \
      --role-name "{{ name }}" \
      --policy-name "${policy}" \
      --color off
  done < <( aws iam list-role-policies --role-name "{{ name }}" --output json | jq -r '.PolicyNames[]' )
  aws iam delete-role \
    --role-name "{{ name }}" \
    --color off
fi

