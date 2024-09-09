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

id=$1
home=$2
cd "${home}"

if [ -z "${S3_BUCKET}" ]; then
  S3_BUCKET=swarms.zerocracy.com
fi
if [ -z "${BAZA_URL}" ]; then
  BAZA_URL=https://www.zerocracy.com
fi

status=$(curl -s "${BAZA_URL}/pop?swarm=${SWARM_ID}&secret=${SWARM_SECRET}" -o pack.zip -w "%{http_code}")
if [ "${status}" == '204' ]; then
  echo 'No jobs to process'
  exit
fi
if [ "${status}" != '200' ]; then
  cat pack.zip
  exit 1
fi

unzip pack.zip -d pack
id=$(cat pack/job.json | jq .id)
rm pack.zip
zip -j pack.zip pack/*

first=baza-j
key="${first}/${id}.zip"

aws s3 cp pack.zip "s3://${S3_BUCKET}/${key}"

aws sqs send-message \
  --queue-url "https://sqs.us-east-1.amazonaws.com/019644334823/${first}" \
  --message-body "Job ${id} needs processing" \
  --message-attributes "job={DataType=String,StringValue='${id}'},swarm={DataType=String,StringValue='baza-pop',more={DataType=String,StringValue='baza-j'}"
