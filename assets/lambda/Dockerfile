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

FROM ruby:3.3

ENV LAMBDA=/var/task
RUN mkdir -p ${LAMBDA}
WORKDIR ${LAMBDA}

RUN curl -Lso /usr/local/bin/aws-lambda-rie \
  https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie \
  && chmod +x /usr/local/bin/aws-lambda-rie

RUN apt-get -qq update \
    && apt-get -qq install -y unzip curl jq zip \
    && curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip \
    && unzip -q awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws \
    && apt-get -qq clean

COPY Gemfile ${LAMBDA}/
ENV BUNDLE_SILENCE_ROOT_WARNING=1
RUN gem install --quiet bundler -v 2.5.18 \
  && bundle install --retry=5 --quiet "--gemfile=${LAMBDA}/Gemfile"

COPY swarm/ /swarm

COPY install.sh .
RUN /bin/bash ${LAMBDA}/install.sh

COPY entry.sh main.rb .
ENTRYPOINT ["/bin/bash", "entry.sh"]
