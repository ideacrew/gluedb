# FROM --platform=linux/amd64 ubuntu:22.04
FROM --platform=linux/amd64 ubuntu:20.04
LABEL author="IdeaCrew"

RUN apt-get update && apt-get install -y lsb-release software-properties-common && apt-get clean all
# add universal repo
RUN add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe"
RUN apt-add-repository -y ppa:rael-gc/rvm

RUN apt-get update && \
    apt-get install -y git gcc openssl libyaml-dev libyaml-cpp-dev curl libffi-dev  libreadline-dev \
                       zlibc libgdbm-dev libncurses-dev autoconf fontconfig unzip zip sshpass bzip2 libxrender1 libxext6 \
                       build-essential libxml2 libxml2-dev libxslt1-dev libz-dev libssl1.0-dev && \
    apt-get autoremove -y
    
#missing libyaml-cpp0.5v5 libffi6 

#second part
WORKDIR /usr/src/
RUN curl -O https://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.10.tar.bz2
RUN tar xjf ruby-2.1.10.tar.bz2
RUN cd ruby-2.1.10 && ./configure && make -j 2
RUN cd ruby-2.1.10 && make install

WORKDIR /usr/src/app
# Adding gems
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock

RUN gem install bundler --version "1.17.3"

# Setting env up
ARG GEM_OAUTH_TOKEN
ENV BUNDLE_GITHUB__COM=x-access-token:"$GEM_OAUTH_TOKEN"

RUN bundle install --jobs 20 --retry 5

COPY .docker/development/mongoid.yml config/mongoid.yml


# FROM --platform=linux/amd64 ghcr.io/ideacrew/gluedb:base AS base

# LABEL author="IdeaCrew"

# # Install required packages/libraries
# RUN apt-get update && \
#     apt-get -yq dist-upgrade && \
#     apt-get install -y git gcc openssl libyaml-dev libyaml-cpp-dev libyaml-cpp0.5v5 libffi-dev libffi6 libreadline-dev \
#                        zlibc libgdbm-dev libncurses-dev autoconf fontconfig unzip zip sshpass bzip2 libxrender1 libxext6 \
#                        build-essential libxml2 libxml2-dev libxslt1-dev && \
#     apt-get autoremove -y

# ENV LANG=C.UTF-8

# WORKDIR /usr/src/app
# # Adding gems
# COPY Gemfile Gemfile
# COPY Gemfile.lock Gemfile.lock

# RUN gem install bundler --version "1.17.3"

# # Setting env up
# ARG GEM_OAUTH_TOKEN
# ENV BUNDLE_GITHUB__COM=x-access-token:"$GEM_OAUTH_TOKEN"

# RUN bundle install --jobs 20 --retry 5

# COPY .docker/development/mongoid.yml config/mongoid.yml

