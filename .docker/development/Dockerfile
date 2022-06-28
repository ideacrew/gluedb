FROM --platform=linux/amd64 ruby:2.5.9 AS base

LABEL author="IdeaCrew"

# Install required packages/libraries
RUN apt-get update && \
    apt-get -yq dist-upgrade && \
    apt-get install -y git gcc openssl libyaml-dev libyaml-cpp-dev libffi-dev libffi6 libreadline-dev \
                       zlibc libgdbm-dev libncurses-dev autoconf fontconfig unzip zip sshpass bzip2 libxrender1 libxext6 \
                       build-essential && \
    apt-get autoremove -y

ENV LANG=C.UTF-8

WORKDIR /usr/src/app
# Adding gems
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock
COPY project_gems project_gems

RUN gem install bundler --version "1.17.3"

# Setting env up
ARG GEM_OAUTH_TOKEN
ENV BUNDLE_GITHUB__COM=x-access-token:"$GEM_OAUTH_TOKEN"

RUN bundle install --jobs 20 --retry 5

COPY .docker/development/mongoid.yml config/mongoid.yml
