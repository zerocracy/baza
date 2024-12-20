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

set -e
set -o pipefail

id=$1
[[ "${id}" =~ ^[0-9]+$ ]]
home=$2
cd "${home}" || exit 1

if [ -z "${MESSAGE_ID}" ]; then
  echo "MESSAGE_ID environment variable is not set: $(printenv | cut -d= -f1 | paste -sd, -)"
  exit 1
fi
if [ -z "${S3_BUCKET}" ]; then
  S3_BUCKET=swarms.zerocracy.com
fi

previous=$(jq -r .messageAttributes.previous.stringValue < event.json)

hops=$(jq -r .messageAttributes.hops.stringValue < event.json)
[[ "${hops}" =~ [0-9]+ ]]

if [ "${hops}" -gt 20 ]; then
  echo "Something is wrong here, too many hops (${hops})"
  exit 1
fi

aws s3 cp "s3://${S3_BUCKET}/${previous}/${id}.zip" pack.zip

read -r -a more <<< "$( jq -r .messageAttributes.more.stringValue < event.json )"

# If nothing left to be processed
if [ "${more[0]}" == 'null' ]; then
  more=()
fi

# Remove current swarm, so it won't be processed again:
for s in "${!more[@]}"; do
  if [[ "${more[s]}" = "${previous}" ]]; then
    unset 'more[s]'
  fi
done

if [ "${#more[@]}" -eq 0 ]; then
  queue=baza-finish
  attrs=(
    "job={DataType=String,StringValue='${id}'}"
    "hops={DataType=Number,StringValue='$((hops + 1))'}"
    "previous={DataType=String,StringValue='${previous}'}"
  )
  msg=$( aws sqs send-message \
    --queue-url "https://sqs.us-east-1.amazonaws.com/019644334823/${queue}" \
    --message-body "Job ${id} finished processing" \
    --message-attributes "$(IFS=, ; echo "${attrs[*]}")" | jq -r .MessageId )
  echo "SQS message ${msg} sent to the ${queue} queue"
  echo "No more swarms to process, it's time to finish"
else
  next="${more[0]}"
  if [[ ! "${next}" =~ ^baza- ]]; then
    cat event.json
    printf "Wrong swarm name '%s' found in '%s'" "${next}" "${more[*]}"
    exit 1
  fi
  aws s3 cp pack.zip "s3://${S3_BUCKET}/${next}/${id}.zip"
  for s in "${!more[@]}"; do
    if [[ "${more[s]}" = "${next}" ]]; then
      unset 'more[s]'
    fi
  done
  attrs=(
    "job={DataType=String,StringValue='${id}'}"
    "hops={DataType=Number,StringValue='$((hops + 1))'}"
    "previous={DataType=String,StringValue='${previous}'}"
  )
  if [ ! "${#more[@]}" -eq 0 ]; then
    attrs+=("more={DataType=String,StringValue='${more[*]}'}")
  fi
  msg=$( aws sqs send-message \
    --queue-url "https://sqs.us-east-1.amazonaws.com/019644334823/${next}" \
    --message-body "Job #${id} needs further processing by '${more[*]}'" \
    --message-attributes "$(IFS=, ; echo "${attrs[*]}")" | jq -r .MessageId )
  echo "SQS message ${msg} sent to the ${next} queue"
  aws s3 rm "s3://${S3_BUCKET}/${previous}/${id}.zip"
  echo "ZIP ($(du -b pack.zip | cut -f1) bytes) moved from ${previous}/${id}.zip to ${next}/${id}.zip"
  if [ "${#more[@]}" -eq 0 ]; then
    echo "The job #${id} now goes to ${next}, this will be its last stop"
  else
    echo "The job #${id} now goes to ${next}, after that it will go to '${more[*]}'"
  fi
fi
