require 'nokogiri'
require 'open-uri'
require 'parallel'
require 'active_support/all'

module Downloader
  class RemoteBlog
    attr_reader :username, :httpd_port

    def initialize(username)
      @username = username
    end

    def self.mirror_post(url)
      post = RemotePost.new(url)
      blog = post.blog
      blog.with_running_httpd do
        with_browser do |browser|
            post.mirror(browser)
        end
      end
    end

    def create_mirror_dir
      FileUtils.mkdir_p("#{out_dir}/#{@username}_files")
    end

    def create_cache_dir
      FileUtils.mkdir_p(RemoteBlog.cached_posts_dir)
    end

    def with_running_httpd
      start_httpd
      begin
        yield
      ensure
        stop_httpd
      end
    end

    def start_httpd
      @httpd_port = RemoteBlog.get_free_port
      puts "Starting httpd:#{@httpd_port}..."
      # >/dev/null 2>/dev/null
      httpd_start_cmd = "cd #{RemoteBlog.cached_posts_dir} && ruby -run -e httpd . -p #{@httpd_port}"
      @httpd_server_process = Process.spawn(httpd_start_cmd, :pgroup => true)
      sleep 3
    end

    def stop_httpd
      Process.kill('TERM', -Process.getpgid(@httpd_server_process))
    end

    def load_assets(posts)
      http_port = RemoteBlog.get_free_port
      putsd "Starting http server on port #{http_port}..."
      create_mirror_dir
      ensure_httpd_started
      
      #process_number = 1 ###!!! to avoid repetitive noise during debugging 
      #Parallel.each(posts, in_processes: process_number, progress: "Mirroring #{posts.size} HTMLs") do |post|
      posts.each do |post|
        url = "http://localhost:#{http_port}/#{post.user.name}/#{File.basename(post.cached_file_path)}"
        putsd url
        `wget -q -nv --timeout=2 -P #{RemoteBlog.out_dir}/#{@username}_files --page-requisites --no-cookies --no-host-directories --span-hosts -E --wait=0 --execute="robots = off" --convert-links #{url} > /dev/null 2>/dev/null`
      end
    end

    def create_index_file(posts)
      putsd 'create_index_file'
      years_and_posts = Hash.new { |h, k| h[k] = [] }
      posts.each do |post|
        next unless post.title.present?
        next unless post.time.present?
        years_and_posts[post.time.year] << post
      end

      create_mirror_dir

      File.write("#{out_dir}/#{@username}.json", {
        posts: posts.map(&:to_json),
        years: years_and_posts
      }.to_json)
    end

    def rebuild_index_file(cached: true)
      putsd 'rebuild_index_file'
      posts = get_posts(cached: cached)
      create_index_file(posts)
    end

    def cached_posts_dir
      return RemoteBlog.cached_posts_dir + "/#{@username}"
    end

    def self.cached_posts_dir
      prefix = Rails.env.test? ? 'test' : ''
      return "scraped/#{prefix}cache"
    end

    def out_dir
      prefix = Rails.env.test? ? 'test' : ''
      return "public/#{prefix}lj/#{@username}"
    end

    def self.get_free_port
      port = 5012
      while port < 7000
        if RemoteBlog.port_open?(port)
          port += 1
        else
          return port
        end
      end
    end

    def self.port_open?(port)
      system("lsof -i:#{port}", out: '/dev/null')
    end

    def mirror
      posts = get_posts(cached: ENV['USE_CACHE'] == '1')
      putsd "Found #{posts.size} posts"

      with_running_httpd do
        mirror_posts(posts)
      end
      
      create_index_file(posts)
      rebuild_index_file(cached: true)
    end

    private

    def mirror_posts(posts)
      # it looks like 8 processes block selenium driver. Use 1 as it works at least
      process_number = 1
      if (process_number_str = ENV['MIRROR_POSTS_PROCESS_NUMBER'])
        process_number = process_number_str.to_i
      end
      
      limiter = RateLimiter.new(5) # max 5 calls per minute
      
      with_browser do |browser|
        # To avoid error
        #   invalid cookie domain
        #       (Session info: chrome=154.0.8037.57)
        # add_session_cookie should be called after initial navigation. So do warm up load first
        profile_url = get_journal_url + "/profile/"
        puts "warm up browser user data, loading #{profile_url}"
        browser.navigate.to(profile_url)
        add_session_cookie(browser)
      
        #Parallel.each(posts, in_processes: process_number, progress: "Mirroring #{posts.size} HTMLs") do |post|
        posts.each do |post|
          next if post.cached? && ENV['REMIRROR'] != '1'
          puts "Will mirror #{post}. Time: #{Time.now}"
          begin
            limiter.call do 
              post.mirror(browser)
            end
          rescue => e
            puts e
            retry
          end
        end
      end
    end

    def add_session_cookie(browser)
      cookies_str = File.read("scraped/session_cookies.txt")
      cookies_str.split('; ').each { |kv| 
        cookie_name, cookie_value = kv.split('=')
        #puts "cookie_name: #{cookie_name}, value: #{cookie_value}"
        browser.manage.add_cookie(name: cookie_name, value: cookie_value)
      }
    end
    
    def with_browser
      puts "blog: with_browser"
      begin
        browser = Chrome.create(headless: true, typ: 'desktop')
      rescue => e
        puts "Browser preparation error:"
        puts e.inspect
        puts e.backtrace
        raise e
      end

      puts "after preparation"
      `pgrep -l chrome`

      yield browser

      puts "before quit"
      `pgrep -l chrome`

      begin
        puts "quitting browser"
        browser.quit
        puts "sleep 3 sec"
        sleep 3 ###!!! 
      rescue => e1
        puts "Browser quitting error:"
        puts e1.inspect
        puts e1.backtrace
      end
    end

    def get_date_range
      start_year = 2007
      start_month = 1

      end_year = Date.today.year
      end_month = Date.today.month

      return start_year, start_month, end_year, end_month

      # "https://www.livejournal.com/view/?type=month&user=#{@username}&y=$year&m=$month"
    end

    def get_posts(cached: false)
      cached_posts_list_path = cached_posts_dir + '/_post_urls.txt'
      if cached && File.exists?(cached_posts_list_path)
        putsd 'loading cached posts...'
        posts = File.open(cached_posts_list_path).readlines.map { |l| RemotePost.new(l.strip, blog: self) }
        puts '...done'
        return posts
      end
      putsd "getting posts... (cached: #{cached}), (cached_posts_list_path: #{cached_posts_list_path})"

      start_year, start_month, end_year, end_month = get_date_range

      years_and_months = []

      (start_year..end_year).each do |year|
        (1..12).each do |month|
          next if year == end_year && month > end_month
          years_and_months << [year, month]
        end
      end

      results = Parallel.map(years_and_months, in_threads: 1) do |year, month|
        get_posts_from_archive_page(year, month)
      end

      posts = results.compact.flatten
      FileUtils.mkdir_p(cached_posts_dir)
      File.open(cached_posts_dir + '/_post_urls.txt', 'w').write(posts.map { |po| po.url }.join("\n"))
      return posts
    end

    def get_journal_url
        return "https://#{@username}.livejournal.com"
    end

    def get_posts_from_archive_page(year, month)
      url = get_journal_url + "/#{year}/#{sprintf('%02d', month)}/"
      putsd "loading url #{url}"
      html = Nokogiri::HTML(read_url(url))
      urls = html.css('a').select { |a| a.attribute('href')&.value =~ %r{://#{@username}.livejournal.com/\d+.html} }.map { |a| a.attribute('href').value }
      putsd "    #{urls.size} for #{year}.#{month}"
      return urls.map { |u| RemotePost.new(u.strip, blog: self) }
    end
  end
end
