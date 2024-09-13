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
[[ "${id}" =~ ^[0-9]+$ ]]
home=$2
cd "${home}"

if [ -z "${S3_BUCKET}" ]; then
  S3_BUCKET=swarms.zerocracy.com
fi

swarm=$(jq -r .messageAttributes.swarm.stringValue < event.json)

aws s3 cp "s3://${S3_BUCKET}/${swarm}/${id}.zip" pack.zip

read -r -a more <<< "$( jq -r .messageAttributes.more.stringValue < event.json )"

if [ "${more[0]}" == 'null' ]; then
  cat event.json
  echo "There is not 'more' found in the JSON, it's an error"
  exit 1
fi

if [ "${#more[@]}" -eq 0 ]; then
  aws sqs send-message \
    --queue-url https://sqs.us-east-1.amazonaws.com/019644334823/baza-finish \
    --message-body "Job ${id} finished processing" \
    --message-attributes "job={DataType=String,StringValue='${id}'},swarm={DataType=String,StringValue='${swarm}'}"
else
  next="${more[0]}"
  if [[ ! "${next}" =~ ^baza- ]]; then
    cat event.json
    printf "Wrong swarm name '%s' found in '%s'" "${next}" "${more[@]}"
    exit 1
  fi
  aws s3 rm "s3://${S3_BUCKET}/${swarm}/${id}.zip"
  aws s3 cp pack.zip "s3://${S3_BUCKET}/${next}/${id}.zip"
  aws sqs send-message \
    --queue-url "https://sqs.us-east-1.amazonaws.com/019644334823/${next}" \
    --message-body "$( printf "Job #${id} needs futher processing by '%s'" "${more[@]}" )" \
    --message-attributes "$( printf "job={DataType=String,StringValue='%d'},swarm={DataType=String,StringValue='%s'},more={DataType=String,StringValue='%s'}" "${id}" "${swarm}" "${more[@]}" )"
fi
