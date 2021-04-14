########################
### app/rails config ###
########################

FROM ruby:2.1.7 AS app

LABEL author="IdeaCrew"

# Install required packages/libraries
RUN apt-get update && \
    apt-get -yq dist-upgrade && \
    apt-get install -y git gcc openssl libyaml-dev libyaml-cpp-dev libyaml-cpp0.5 libffi-dev libffi6 libreadline-dev \
                       zlibc libgdbm-dev libncurses-dev autoconf fontconfig unzip zip sshpass bzip2 libxrender1 libxext6 \
                       build-essential && \
    apt-get autoremove -y

# Configure bundler and PATH, install bundler version
ENV LANG=C.UTF-8 \
    GEM_HOME=/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3
ENV BUNDLE_PATH $GEM_HOME
ENV BUNDLE_APP_CONFIG=$BUNDLE_PATH \
    BUNDLE_BIN=$BUNDLE_PATH/bin
ENV PATH $BUNDLE_BIN:$GEM_HOME/gems/bin:$PATH

ARG BUNDLER_VERSION_OVERRIDE
ENV BUNDLER_VERSION=$BUNDLER_VERSION_OVERRIDE
RUN gem install bundler:$BUNDLER_VERSION

# Configure app home directory
ENV HOME /edidb
RUN mkdir -p $HOME
WORKDIR $HOME
COPY . $HOME
RUN mkdir -p /edidb/log

# Adding gems
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock

# Setting env up
ARG SECRET_KEY_BASE
ARG DB_HOST
ARG DB_PORT
ARG DB_DATABASE
ARG RABBITMQ_URL
ARG DEVISE_SECRET_KEY
ENV RAILS_ENV='production'
ENV NODE_ENV='production'
ENV DB_HOST=$DB_HOST
ENV DB_PORT=$DB_PORT
ENV DB_DATABASE=$DB_DATABASE
ENV RABBITMQ_URL=$RABBITMQ_URL
ENV SECRET_KEY_BASE=$SECRET_KEY_BASE
ENV DEVISE_SECRET_KEY=$DEVISE_SECRET_KEY

RUN bundle install --jobs 20 --retry 5 --without development test 

RUN bundle exec rake assets:precompile 

#CMD ["./entrypoints/docker-entrypoint.sh"]


########################
### web/nginx config ###
######################## 

FROM nginx:1.17.6-alpine as web

RUN mkdir /edidb

# copy assets from the app build and nginx config
COPY --from=app /edidb/public /edidb/
COPY .docker/production/nginx.conf /etc/nginx/conf.d/edidb.conf
RUN mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf-bkp

