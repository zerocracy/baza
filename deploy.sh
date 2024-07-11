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

cd $(dirname $0)

if [ ! -e /code/z/j ]; then
  echo "You should git clone git@github.com:zerocracy/j.git to /code/z/j"
  exit 1
fi

trap 'git rm -f -r j && rm -rf j && git checkout -- .gitignore' EXIT
rm -rf j
mkdir j
cp -R /code/z/j/j.gemspec j
cp -R /code/z/j/judges j
cp -R /code/z/j/lib j
sed -i -s 's|j/||g' .gitignore
git add j
bundle update

cp /code/home/assets/zerocracy/baza.yml config.yml
git add config.yml
git add Gemfile.lock
git add .gitignore
git commit -m 'config.yml for heroku and j sources'
trap 'git reset HEAD~1 && rm -rf j && rm -f config.yml && git checkout -- .gitignore && git checkout -- Gemfile.lock' EXIT

git push heroku master -f
rm -f target/pgsql-config.yml
bundle exec rake liquibase
