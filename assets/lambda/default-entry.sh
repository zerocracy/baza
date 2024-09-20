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
if [ -z "${id}" ]; then
  echo "The first argument must be the ID of the job to process"
  exit 1
fi
[[ "${id}" =~ ^[0-9]+$ ]]

home=$2
if [ -z "${home}" ]; then
  echo "The second argument must be the directory where 'base.fb' is located"
  exit 1
fi

if [ ! -e "${home}/job.json" ]; then
  echo "There is no JSON description of the job, something is going wrong"
  exit 1
fi

if [ ! -e "${home}/base.fb" ]; then
  echo "There is no Factbase, something is going wrong"
  exit 1
fi

self=$(dirname "$0")

options=(
  '--quiet'
  '--summary'
  '--max-cycles=3'
  '--no-log'
)
opts=$( jq -r '.options | keys[] as $k | "\($k)\t\(.[$k])"' "${home}/job.json" )
while IFS= read -r ln; do
  options+=("--option=$( echo "${ln}" | cut -f1 )=$( echo "${ln}" | cut -f2 )")
done <<< "${opts}"

if [ -e "${self}/lib" ]; then
  options+=('--lib' "${self}/lib")
fi

export BUNDLE_GEMFILE="${self}/Gemfile"

set -x
bundle exec judges --verbose update "${options[@]}" "${self}/judges" "${home}/base.fb"
