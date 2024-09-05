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

# This should either be "arm64" or "x86_64". If you change this value,
# make sure the EC2 image that you are using is of the same architecture.
arch=x86_64

uri="git@github.com:{{ github }}.git"
if [ ! -s "${HOME}/.ssh/id_rsa" ]; then
  uri="https://github.com/{{ github }}"
fi

attempt=0
while true; do
  git clone -b "{{ branch }}" --depth=1 --single-branch "${uri}" swarm && break
  ((++attempt))
  if [ "${attempt}" -gt 8 ]; then exit 1; fi
  sleep "${attempt}"
done
git --git-dir swarm/.git rev-parse HEAD | tr '[:lower:]' '[:upper:]' > head.txt
version=$(git --git-dir swarm/.git rev-parse --short HEAD)
rm -rf swarm/.git

aws ecr get-login-password --region "{{ region }}" | docker login --username AWS --password-stdin "{{ repository }}"

this="baza-{{ name }}"

if ! aws ecr describe-repositories --repository-names "{{ name }}" --region "{{ region }}"; then
  aws ecr create-repository \
    --color off \
    --repository-name "{{ name }}" \
    --region "{{ region }}" \
    --image-tag-mutability MUTABLE
fi

image="{{ repository }}/{{ name }}:latest"
docker pull "${image}" --platform "linux/${arch}" || echo 'Maybe it is absent'
docker build . -t "${image}" --platform "linux/${arch}"
docker push "${image}" --platform "linux/${arch}"

# Create new IAM role, which will be assumed by Lambda function executions:
if ! aws iam get-role --role-name "{{ name }}"; then
  aws iam create-role \
    --color off \
    --role-name "{{ name }}" \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": { "Service": "lambda.amazonaws.com" },
            "Action": "sts:AssumeRole"
          }
        ]
      }'
  echo "Now, we have to wait a bit, to make sure the role is warmed up by AWS IAM..."
  sleep 15
fi

# Allow this role to read/write SQS events:
if ! aws iam get-role-policy --role-name "{{ name }}" --policy-name 'access'; then
  aws iam put-role-policy \
    --color off \
    --role-name "{{ name }}" \
    --policy-name 'access' \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Action": [ "sqs:*" ],
            "Effect": "Allow",
            "Resource": "arn:aws:sqs:{{ region }}:{{ account }}:{{ name }}"
          },
          {
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": "arn:aws:s3:::{{ bucket }}/*"
          },
          {
            "Effect": "Allow",
            "Action": [
              "s3:ListBucket",
              "s3:GetObject",
              "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::{{ bucket }}/{{ name }}/*"
          },
          {
            "Effect": "Allow",
            "Action": [
              "cloudformation:DescribeStacks",
              "cloudformation:ListStackResources",
              "cloudwatch:ListMetrics",
              "cloudwatch:GetMetricData",
              "ec2:DescribeSecurityGroups",
              "ec2:DescribeSubnets",
              "ec2:DescribeVpcs",
              "kms:ListAliases",
              "iam:GetPolicy",
              "iam:GetPolicyVersion",
              "iam:GetRole",
              "iam:GetRolePolicy",
              "iam:ListAttachedRolePolicies",
              "iam:ListRolePolicies",
              "iam:ListRoles",
              "lambda:*",
              "states:DescribeStateMachine",
              "states:ListStateMachines",
              "tag:GetResources",
              "xray:GetTraceSummaries",
              "xray:BatchGetTraces"
            ],
            "Resource": "*"
          },
          {
            "Effect": "Allow",
            "Action": [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:{{ region }}:{{ account }}:log-group:/aws/lambda/*"
          },
          {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "*",
            "Condition": {
              "StringEquals": {
                "iam:PassedToService": "lambda.amazonaws.com"
              }
            }
          }
        ]
      }'
fi

# Create or update Lambda function:
if aws lambda get-function --function-name "{{ name }}" --region "{{ region }}"; then
  aws lambda update-function-code \
    --color off \
    --function-name "{{ name }}" \
    --architectures "${arch}" \
    --region "{{ region }}" \
    --image-uri "${image}" \
    --publish
else
  aws lambda create-function \
    --color off \
    --function-name "{{ name }}" \
    --region "{{ region }}" \
    --architectures "${arch}" \
    --description "Process jobs of swarm #{{ swarm }} at {{ github }}" \
    --package-type Image \
    --code "ImageUri=${image}" \
    --tags "VERSION=${version}" \
    --role "arn:aws:iam::{{ account }}:role/{{ name }}"
fi

# Create new SQS queue for this new Lambda function:
if ! aws sqs get-queue-url --queue-name "{{ name }}" --region "{{ region }}"; then
  aws sqs create-queue \
    --color off \
    --queue-name "{{ name }}" \
    --region "{{ region }}"
fi

# Make sure all new SQS events trigger Lambda function execution:
arn="arn:aws:sqs:{{ region }}:{{ account }}:{{ name }}"
fn="arn:aws:lambda:{{ region }}:{{ account }}:function:{{ name }}"
if ! ( aws lambda list-event-source-mappings --event-source-arn "${arn}" --function-name "${fn}" --region "{{ region }}" | grep "\"${fn}\"" ); then
  aws lambda create-event-source-mapping \
    --color off \
    --event-source-arn "${arn}" \
    --batch-size=1 \
    --function-name "${fn}" \
    --region "{{ region }}"
fi
