FROM quay.io/evl.ms/fullstaq-ruby:3.2.2-jemalloc-bullseye-slim

ARG NODE_MAJOR=20
ARG YARN_VERSION='3.3.0'
ARG NODE_OPTIONS=--openssl-legacy-provider

### deb http://deb.debian.org/debian bullseye main
### deb http://deb.debian.org/debian-security bullseye-security main
### deb http://deb.debian.org/debian bullseye-updates main

RUN cat /etc/apt/sources.list \
  && echo "deb [check-valid-until=no] http://archive.debian.org/debian bullseye main" > /etc/apt/sources.list.d/bullseye-backports.list \
  && sed -i '/deb http:\/\/deb.debian.org\/debian bullseye main/d' /etc/apt/sources.list \
  && sed -i '/deb http:\/\/security.debian.org\/debian-security bullseye-security main/d' /etc/apt/sources.list \
  && sed -i -e '/deb http:\/\/deb.debian.org\/debian-security bullseye-security main/d' -e 's/deb.debian.org/archive.debian.org/g'  /etc/apt/sources.list \
  && cat /etc/apt/sources.list \
  && apt-get -o Acquire::Check-Valid-Until=false update

### deb http://archive.debian.org/debian bullseye-updates main

# ENV LOCALE=ru_RU
#     locales && \
#   dpkg-reconfigure -f noninteractive tzdata && \
#   sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
#   sed -i -e 's/# ${LOCALE}.UTF-8 UTF-8/${LOCALE}.UTF-8 UTF-8/' /etc/locale.gen && \
#   echo "LANG=${LOCALE}.UTF-8" > /etc/default/locale && \
#   dpkg-reconfigure --frontend=noninteractive locales && \
#   update-locale LANG=${LOCALE}.UTF-8

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
    unzip \
    wget \
    mc \
    nano \
    tmux \
  && update-locale LANG=C.UTF-8 LC_ALL=C.UTF-8 \
  && apt-get clean \
  && rm -rf /var/cache/apt/archives/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && truncate -s 0 /var/log/*log

# ENV LANG=${LOCALE}.UTF-8
# ENV LANGUAGE=${LOCALE}.UTF-8
# ENV LC_ALL=${LOCALE}.UTF-8

### ### 114.0.5735.198-1
### ENV CHROME_VERSION=119.0.6045.199-1
### # As https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable
### #    is not available use
### #    https://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/
### RUN echo "Install Google Chrome ${CHROME_VERSION}" \
###   && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
###   && wget -q https://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_amd64.deb \
###   && apt-get install -y ./google-chrome-stable_${CHROME_VERSION}_amd64.deb
### 
### # && echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' | tee /etc/apt/sources.list.d/google-chrome.list \
### # && apt-get update \

# installing google-chrome-stable 
# TODO: figure out how to download particular version.
# Until then sync version of browser with chromedriver version below
RUN apt-get update && \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-linux-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y google-chrome-stable

# TODO: should be equal to ${CHROME_VERSION}
ENV CHROMEDRIVER_VERSION=154.0.8037.57
RUN mkdir ~/.webdrivers/ \
    && wget https://storage.googleapis.com/chrome-for-testing-public/${CHROMEDRIVER_VERSION}/linux64/chromedriver-linux64.zip \
    && unzip chromedriver-linux64.zip \
    && mv ./chromedriver-linux64/chromedriver ~/.webdrivers/

COPY Gemfile* /app/
WORKDIR /app

RUN gem install bundler -v 2.4.21 && \
  bundle config --global silence_root_warning 1 && \
  bundle config --local deployment 'true' && \
  bundle config --local without 'development test' && \
  bundle config --local clean 'true' && \
  bundle config --local no-cache 'true' && \
  bundle install --retry 5

#   bundle config set frozen false && \
#   bundle update webdrivers && \
#   bundle update selenium-webdriver && \

COPY package.json /app/
RUN yarn install --frozen-lockfile

COPY . /app
