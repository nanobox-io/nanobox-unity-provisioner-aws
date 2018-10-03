FROM ruby:2.3-alpine

# set some ARGs for ssh key management
ARG SSH_KEY_PUB
ARG SSH_KEY_PRIV

# setup the app dir
RUN mkdir /app
WORKDIR /app

# install necessary packages
RUN apk update && \
    apk add \
      # let's add some real shells for dev
      bash zsh \
      # build tools, for compiling
      build-base \
      # ncurses for pry
      ncurses \
      # we pull some gems directly from github
      git openssh-client \
      # we need libxml for aws client
      libxml2-dev
      
# set the ssh key (normally we'd NOT persist this, but since this is dev we're ok)
COPY .docker/dev/.ssh /root/.ssh
RUN echo "$SSH_KEY_PRIV" > /root/.ssh/id_rsa && \
    echo "$SSH_KEY_PUB" > /root/.ssh/id_rsa.pub && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/*

# bundle install
COPY Gemfile Gemfile.lock ./
RUN bundle install
