FROM ruby:2.6

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN cat /etc/apt/sources.list

### # deb http://snapshot.debian.org/archive/debian/20220418T000000Z bullseye main
### deb http://deb.debian.org/debian bullseye main
### # deb http://snapshot.debian.org/archive/debian-security/20220418T000000Z bullseye-security main
### deb http://security.debian.org/debian-security bullseye-security main
### # deb http://snapshot.debian.org/archive/debian/20220418T000000Z bullseye-updates main
### deb http://deb.debian.org/debian bullseye-updates main

RUN echo "deb [check-valid-until=no] http://archive.debian.org/debian bullseye main" > /etc/apt/sources.list.d/bullseye-backports.list
RUN sed -i '/deb http:\/\/deb.debian.org\/debian bullseye main/d' /etc/apt/sources.list
RUN sed -i '/deb http:\/\/security.debian.org\/debian-security bullseye-security main/d' /etc/apt/sources.list

RUN sed -i -e 's/deb.debian.org/archive.debian.org/g' -e 's|security.debian.org|archive.debian.org|g' /etc/apt/sources.list
RUN sed -i '/deb http:\/\/deb.debian.org\/debian bullseye main/d' /etc/apt/sources.list

RUN cat /etc/apt/sources.list

RUN apt-get -o Acquire::Check-Valid-Until=false update

RUN apt-get update -qq && apt-get install -y nodejs libnss3 libgconf-2-4 mc nano tmux

RUN echo "Installing chromedriver" \
&& wget https://chromedriver.storage.googleapis.com/LATEST_RELEASE \
&& wget https://chromedriver.storage.googleapis.com/`cat LATEST_RELEASE`/chromedriver_linux64.zip \
&& unzip chromedriver_linux64.zip \
&& mv chromedriver /usr/bin/

# the last version supported by ^
ENV CHROME_VERSION=114.0.5735.198-1
# As https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable
#    is not available use
#    https://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/
RUN echo "Install Google Chrome ${CHROME_VERSION}" \
&& wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
&& echo 'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main' | tee /etc/apt/sources.list.d/google-chrome.list \
&& apt-get update \
&& wget -q https://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_amd64.deb \
&& apt-get install -y ./google-chrome-stable_${CHROME_VERSION}_amd64.deb \
&& apt-get clean -y

# && apt-get install -y google-chrome-stable && 

# Copy app and install gems
RUN mkdir -p /home/app/webapp
WORKDIR /home/app/webapp
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.4.22 &&  bundle config --global silence_root_warning 1 && bundle install --jobs 20 --retry 5 --deployment --without development test

COPY  . .
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
