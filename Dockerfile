FROM quay.io/evl.ms/fullstaq-ruby:3.2.2-jemalloc-bullseye-slim

ARG NODE_MAJOR=20
ARG YARN_VERSION='3.3.0'
ARG NODE_OPTIONS=--openssl-legacy-provider

RUN echo 'Europe/Riga' > /etc/timezone && \
  apt-get update && \
  apt-get install -yq --no-install-recommends \
    ca-certificates \
    curl \
    gnupg && \
  mkdir -p /etc/apt/keyrings && \
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarn.gpg && \
  echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
    build-essential \
    vim \
    tmux \
    libpq-dev \
    zsh \
    git \
    time \
    gnupg \
    tzdata \
    yarn \
    nodejs \
    lsb-release \
    locales \
    libyaml-dev \
  && update-locale LANG=C.UTF-8 LC_ALL=C.UTF-8 \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

COPY Gemfile* /app/
WORKDIR /app
RUN bundle config --global silence_root_warning 1 && \
  bundle config --local deployment 'true' && \
  bundle config --local without 'development test' && \
  bundle config --local clean 'true' && \
  bundle config --local no-cache 'true' && \
  bundle install --retry 5

COPY package.json /app/
RUN yarn install --frozen-lockfile

COPY . /app
