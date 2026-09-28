FROM quay.io/evl.ms/fullstaq-ruby:3.2.2-jemalloc-bullseye-slim

ARG NODE_MAJOR=20
ARG YARN_VERSION='3.3.0'
ARG NODE_OPTIONS=--openssl-legacy-provider

### RUN cat /etc/apt/sources.list

### # deb http://snapshot.debian.org/archive/debian/20220418T000000Z bullseye main
### deb http://deb.debian.org/debian bullseye main
### # deb http://snapshot.debian.org/archive/debian-security/20220418T000000Z bullseye-security main
### deb http://security.debian.org/debian-security bullseye-security main
### # deb http://snapshot.debian.org/archive/debian/20220418T000000Z bullseye-updates main
### deb http://deb.debian.org/debian bullseye-updates main

RUN echo "deb [check-valid-until=no] http://archive.debian.org/debian bullseye main" > /etc/apt/sources.list.d/bullseye-backports.list \
    && sed -i '/deb http:\/\/deb.debian.org\/debian bullseye main/d' /etc/apt/sources.list \
    && sed -i '/deb http:\/\/security.debian.org\/debian-security bullseye-security main/d' /etc/apt/sources.list \
    && sed -i -e 's/deb.debian.org/archive.debian.org/g' -e 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list \
    && sed -i '/deb http:\/\/deb.debian.org\/debian bullseye main/d' /etc/apt/sources.list \
    && cat /etc/apt/sources.list \
    && apt-get -o Acquire::Check-Valid-Until=false update

### # the last version supported by ^
### ENV CHROME_VERSION=114.0.5735.198-1
### # As https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable
### #    is not available use
### #    https://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/
### RUN echo "Install Google Chrome ${CHROME_VERSION}" \
###   && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
###   && echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' | tee /etc/apt/sources.list.d/google-chrome.list \
###   && apt-get update \
###   && wget -q https://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_amd64.deb \
###   && apt-get install -y ./google-chrome-stable_${CHROME_VERSION}_amd64.deb

RUN echo 'Europe/Moscow' > /etc/timezone && \
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
    mc \
    nano \
    tmux \
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
