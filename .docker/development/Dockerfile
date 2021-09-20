# FROM public.ecr.aws/ideacrew/enroll:base as app
FROM ruby:2.1.1 as gluedb

ENV HOME /gluedb
RUN mkdir -p $HOME
WORKDIR $HOME

# RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-key list | grep “expired:”

RUN apt-get update \
  && apt-get -yq dist-upgrade \
  && apt-get install -y tzdata build-essential vim \
  && apt-get autoremove -y --force-yes

# Configure bundler and PATH
ENV GEM_HOME="/usr/local/bundle"

ENV LANG=C.UTF-8 \
  BUNDLE_PATH=$GEM_HOME \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3
ENV BUNDLE_BIN=$BUNDLE_PATH/bin

RUN mkdir -p $BUNDLE_PATH && mkdir -p $BUNDLE_BIN

ENV PATH $GEM_HOME/bin:$GEM_HOME/gems/bin:$PATH

COPY . $HOME

RUN gem install --source "https://rubygems.org" bundler --version '2.2.24'

RUN cd $HOME && bundle install && bundle binstubs bundler
# RUN cd $HOME && yarn add @rails/webpacker@5.4.0 && yarn add --dev webpack-dev-server
# RUN cd $HOME && rails webpacker:install:erb
# RUN cd $HOME && yarn add bootstrap && yarn add @popperjs/core

RUN unset BUNDLE_PATH
RUN unset BUNDLE_BIN
