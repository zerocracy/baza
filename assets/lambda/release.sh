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

git clone -b "{{ branch }}" --depth=1 --single-branch "${uri}" swarm
git --git-dir swarm/.git rev-parse HEAD | tr '[:lower:]' '[:upper:]' > head.txt

aws ecr get-login-password --region "{{ region }}" | docker login --username AWS --password-stdin "{{ repository }}"

docker build . -t baza --platform linux/amd64

this="baza-{{ name }}"

if ! aws ecr get-repository-policy --repository-name "{{ name }}" --region "{{ region }}"; then
  aws ecr create-repository --repository-name "{{ name }}" --region "{{ region }}" --image-tag-mutability MUTABLE
fi

image="{{ repository }}/{{ name }}:latest"
docker tag baza "${image}"
docker push "${image}"

if aws lambda get-function --function-name "{{ name }}" --region "{{ region }}"; then
  aws lambda update-function-code --function-name "{{ name }}" \
    --region "{{ region }}" \
    --image-uri "${image}" \
    --version "$(cat head.txt)" \
    --publish
else
  # Create new IAM role, which will be assumed by Lambda function executions:
  aws iam create-role --role-name "{{ name }}" \
    --assume-role-policy-document '
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": { "Service": "lambda.amazonaws.com" },
            "Action": "sts:AssumeRole"
          }
        ]
      }'

  # Allow this role to read/write SQS events:
  aws iam put-role-policy --role-name "{{ name }}" \
    --policy-name 'Read/write SQS messages' \
    --policy-document '
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Action": ["sqs:*"],
            "Effect": "Allow",
            "Resource": "arn:aws:sqs:{{ region }}:{{ account }}:{{ name }}"
          }
        ]
      }'

  # Allow this role to read/write S3 objects:
  aws iam put-role-policy --role-name "{{ name }}" \
    --policy-name 'Read/write S3 objects' \
    --policy-document '
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": "arn:aws:s3:::{{ bucket }}/*"
          },
          {
            "Effect": "Allow",
            "Action": [
              "s3:ListBucket"
              "s3:GetObject",
              "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::{{ bucket }}/{{ name }}/*"
          }
        ]
      }'

  # Create new Lambda function:
  aws lambda create-function --function-name "{{ name }}" \
    --region "{{ region }}" \
    --package-type Image \
    --code "ImageUri=${image}" \
    --version "$(cat head.txt)" \
    --role "arn:aws:iam::{{ account }}:role/{{ name }}"

  # Create new SQS queue for this new Lambda function:
  aws sqs create-queue --queue-name "{{ name }}" --region "{{ region }}"

  # Make sure all new SQS events trigger Lambda function execution:
  aws lambda aws create-event-source-mapping \
    --event-source-arn "arn:aws:sqs:{{ region }}:{{ account }}:{{ name }}" \
    --batch-size=1 \
    --function-name "{{ name }}" \
    --region "{{ region }}"
fi
