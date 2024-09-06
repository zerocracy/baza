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

FROM public.ecr.aws/lambda/ruby:3.2

# hadolint ignore=DL3033
RUN yum update -y \
  && yum install -y \
    make-* automake gcc gcc-c++ kernel-devel \
    gcc readline-devel libicu-devel zlib-devel \
    openssl-devel openssl \
    wget tar gzip \
    libyaml libyaml-devel \
    git \
  && yum clean all

COPY install-pgsql.sh /tmp
RUN /bin/bash /tmp/install-pgsql.sh > /dev/null

COPY Gemfile ${LAMBDA_TASK_ROOT}/
RUN gem install --quiet bundler -v 2.5.18 \
  && bundle install --quiet "--gemfile=${LAMBDA_TASK_ROOT}/Gemfile"

COPY swarm/ /swarm

COPY install.sh /tmp
RUN /bin/bash /tmp/install.sh

COPY entry.rb ${LAMBDA_TASK_ROOT}/

RUN rm -rf /tmp/*

CMD ["entry.go"]
