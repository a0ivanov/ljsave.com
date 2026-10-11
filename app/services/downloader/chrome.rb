if Rails.env.production? == false
  require 'rubygems'
  require 'selenium-webdriver'
  require 'pathname'
  require 'fileutils'
  require 'time'
  require 'active_support/all'
end

module Downloader
  class ProxyError < StandardError; end

  class Chrome
    def self.create(headless: true, typ: 'desktop')
      # `killall chromium-browser > /dev/null 2>&1`
      # `killall chromedriver > /dev/null 2>&1`
      # `killall google-chrome > /dev/null 2>&1`
      # `killall chrome_crashpad > /dev/null 2>&1`
      # `pkill -f chrome`
      # `pkill -f chromedriver`
      # `pkill -f chrome_crashpad`
      # `rm -rf /tmp/.com.google.Chrome.*`
      
      current_dir = File.expand_path(File.dirname(__FILE__))
      datadir = Pathname(current_dir).dirname.to_s
      datadir = Pathname(datadir).dirname.to_s
      datadir = "#{datadir}/../lj_chrome_data/"
      puts "Chrome data directory: #{datadir}"
      #`rm -f #{datadir}SingletonLock`
      #`rm -f #{datadir}SingletonCookie`
      
      # chromedriver binary downloaded from
      #    https://googlechromelabs.github.io/chrome-for-testing/
      # is supposed to be put at ~/.webdrivers
      #    per /usr/local/bundle/ruby/webdrivers-5.2.0/webdrivers/common.rb 
      #Webdrivers::Chromedriver.required_version = '154.0.8037.57'
      
      options = Selenium::WebDriver::Chrome::Options.new #/usr/bin/google-chrome
      options.add_argument('--ignore-certificate-errors')
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-popup-blocking')
      options.add_argument('--disable-translate')
      options.add_argument('--disable-web-security')
      options.add_argument('--allow-running-insecure-content')
      options.add_argument('--disable-accelerated-video')
      options.add_argument('--disable-gpu')
      options.add_argument('--process-per-tab')

      options.add_argument('--disable-notifications')
      options.add_argument('--disable-desktop-notifications')
      options.add_argument('--disable-component-update')
      options.add_argument('--disable-datasaver-prompt')
      options.add_argument('--disable-hang-monitor')
      options.add_argument('--autoplay-policy=user-gesture-required')
      options.add_argument('--no-default-browser-check')

      options.add_argument('--disable-features=site-per-process') # Disables OOPIF
      options.add_argument('--blink-settings=imagesEnabled=false')
      
      # this value causes spam in chrome log
      #options.add_argument('--disk-cache-size=2147483648')
      options.add_argument('--disk-cache-size=2000000000') # 2GB

      # options.add_argument('--disable-extensions')
      # options.add_argument('--proxy-server=socks5://localhost:7777')
      #   options.add_argument('--proxy-server=77.111.245.10:443')
      options.add_argument("--user-data-dir=#{datadir}")

      if headless != false && ENV['NO_HEADLESS'] != '1'
        options.add_argument('--headless')
      end

      if ENV['PROXY']
        options.add_argument(%{--proxy-server=#{ENV['PROXY']}})
        options.add_argument(%{--user-agent="#{OPERA_USERAGENT}"})
      end

      ###!!! note: it is not checked yet. if it requires installation of Russian system locale
      options.add_preference("intl.accept_languages", 'ru-RU')
      # this is not needed and not enough
      # options.add_argument('--lang=ru-RU')

      options.add_argument('--disable-search-engine-choice-screen')
      # https://techhelpz.online/selenium-chromedriver-session-not-created-devtoolsactiveport-file-does-not-exist-fix/
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--remote-debugging-port=9222")
      options.add_argument("--enable-unsafe-swiftshader")
      
      begin 
        driver = Selenium::WebDriver.for :chrome, options: options
      rescue Selenium::WebDriver::Error::SessionNotCreatedError
        puts 'browser data corrupted, recovering'
        `pkill -f chrome`
        `rm -f #{datadir}SingletonLock`
        `rm -f #{datadir}SingletonCookie`
        `rm -f #{datadir}Default/Preferences`
        `rm -f "#{datadir}Local State"`
        puts 'launch browser after cleanup'
        driver = Selenium::WebDriver.for :chrome, options: options
      end
      
      return driver
    end
  end
end
