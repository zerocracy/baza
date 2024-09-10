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

swarm=$(cat event.json | jq -r .messageAttributes.swarm.stringValue)

aws s3 cp "s3://${S3_BUCKET}/${swarm}/${id}.zip" pack.zip

more=()
while IFS=' ' read -r s; do
  if [ "${s}" != "${swarm}" ]; then
    more+=("${s}")
  fi
done < <( cat event.json | jq -r .messageAttributes.more.stringValue )

if [ "${#more[@]}" -eq 0 ]; then
  aws sqs send-message \
    --queue-url https://sqs.us-east-1.amazonaws.com/019644334823/baza-finish \
    --message-body "Job ${id} finished processing" \
    --message-attributes "job={DataType=String,StringValue='${id}'},swarm={DataType=String,StringValue='${swarm}'}"
else
  next=${more[0]}
  aws s3 rm "s3://${S3_BUCKET}/${swarm}/${id}.zip"
  aws s3 cp pack.zip "s3://${S3_BUCKET}/${next}/${id}.zip"
  aws sqs send-message \
    --queue-url "https://sqs.us-east-1.amazonaws.com/019644334823/${next}" \
    --message-body "Job ${id} next futher processing by '${more[@]}'" \
    --message-attributes "job={DataType=String,StringValue='${id}'},swarm={DataType=String,StringValue='${swarm}'},more={DataType=String,StringValue='${more[@]}'}"
fi

