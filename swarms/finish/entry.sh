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
if [ -z "${BAZA_URL}" ]; then
  BAZA_URL=https://www.zerocracy.com
fi

hops=$(jq -r .messageAttributes.hops.stringValue < event.json)
[[ "${hops}" =~ [0-9]+ ]]

previous=$( jq -r .messageAttributes.previous.stringValue < event.json )
key="${previous}/${id}.zip"

aws s3 cp "s3://${S3_BUCKET}/${key}" pack.zip

attempt=0
while true; do
  ((++attempt))
  status=$( curl --request PUT --silent \
    "${BAZA_URL}/finish?id=${id}&swarm=${SWARM_ID}&secret=${SWARM_SECRET}" \
    --data-binary '@pack.zip' --output http.txt \
    --connect-timeout 10 --max-time 300 \
    --header "User-Agent: ${SWARM_NAME}" \
    --header 'Content-Type: application/octet-stream' -w "%{http_code}" )
  echo "PUT ${BAZA_URL}/finish returned HTTP #${status}"
  if [ "${status}" -lt 500 ]; then break; fi
  echo "HTTP response: $(cat http.txt)"
  if [ "${attempt}" -gt 8 ]; then exit 1; fi
  sleep "${attempt}"
done
if [ "${status}" != '200' ]; then
  cat http.txt
  echo "Failed to finish (code=${status})"
  exit 1
fi

aws s3 rm "s3://${S3_BUCKET}/${key}"

echo "Job #${id} processing finished (after ${hops} hops)"
