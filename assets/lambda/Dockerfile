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

RUN yum update -y
RUN yum install -y make automake gcc gcc-c++ kernel-devel \
  gcc readline-devel libicu-devel zlib-devel \
  openssl-devel openssl \
  wget tar gzip \
  libyaml libyaml-devel

RUN wget https://ftp.postgresql.org/pub/source/v16.1/postgresql-16.1.tar.gz \
  && tar -xvzf postgresql-16.1.tar.gz \
  && cd postgresql-16.1 \
  && ./configure --bindir=/usr/bin --with-openssl \
  && make -C src/bin install \
  && make -C src/include install \
  && make -C src/interfaces install

COPY Gemfile ${LAMBDA_TASK_ROOT}/
COPY Gemfile.lock ${LAMBDA_TASK_ROOT}/
COPY entry.rb ${LAMBDA_TASK_ROOT}/
RUN gem install bundler && bundle install

WORKDIR /z

{{ installs }}

RUN rm -rf /z/swarms
COPY swarms /z
CMD ["entry.rb"]
