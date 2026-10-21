require 'nokogiri'
require 'open-uri'
require 'parallel'
require 'active_support/all'

require 'zlib'
require 'fileutils'
require 'find'

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
      #rebuild_index_file(cached: true)
    end

    private

    # Deepseek provided
    def ungzip_css(wget_exported_root_path, extensions_array)      
      # Normalize extensions: strip leading dots, downcase, make a Set for fast lookup
      extensions = extensions_array.map { |e| e.sub(/\A\./, '').downcase }.to_set
      raise "No extensions provided" if extensions.empty?
      
      #puts "Root:       #{wget_exported_root_path}"
      puts "Extensions: #{extensions.to_a.sort.join(', ')}"
      
      # Precompute the regex once:
      #   matches ".EXT.gz" followed by a boundary char (or end of line/string)
      #   captures the ".EXT" prefix so we can strip only the ".gz"
      # Group 1 = ".ext" (case-insensitive), Group 2 = trailing boundary
      ext_pattern = extensions.map { |e| Regexp.escape(e) }.join('|')
      gz_ref_re   = /(\.(?:#{ext_pattern}))\.gz(\b|["'\)\?#]|\z)/i
      
      # Files whose *contents* we rewrite (i.e., text formats that may reference assets)
      text_extensions = %w[html htm css js json svg xml txt].to_set
      
      def gzipped?(path)
        File.open(path, 'rb') { |f| f.read(2) == "\x1f\x8b".b }
      rescue
        false
      end
      
      # ---------------------------------------------------------------------------
      # Step 1: Rename/decompress downloaded files ending in ".EXT.gz" -> ".EXT"
      # ---------------------------------------------------------------------------
      gz_suffix_re = /\.(#{ext_pattern})\.gz\z/i
      
      Find.find(wget_exported_root_path) do |path|
        next unless File.file?(path)
        m = path.match(gz_suffix_re)
        next unless m
      
        target = path.sub(gz_suffix_re, ".#{m[1]}")
        puts "Fixing: #{path}"
        puts "     -> #{target}"
      
        if gzipped?(path)
          begin
            Zlib::GzipReader.open(path) do |gz|
              File.open(target, 'wb') { |out| IO.copy_stream(gz, out) }
            end
            File.delete(path)
            puts "     (decompressed)"
          rescue Zlib::GzipFile::Error => e
            warn "     ! Decompress failed: #{e.message} — renaming instead"
            FileUtils.mv(path, target)
          end
        else
          FileUtils.mv(path, target)
          puts "     (renamed, content was not gzipped)"
        end
      end
      
      # ---------------------------------------------------------------------------
      # Step 2: Rewrite references in text files: ".EXT.gz" -> ".EXT"
      # ---------------------------------------------------------------------------
      Find.find(wget_exported_root_path) do |path|
        next unless File.file?(path)
      
        ext = File.extname(path).sub(/\A\./, '').downcase
        next unless text_extensions.include?(ext)
      
        content  = File.binread(path)
        replaced = content.gsub(gz_ref_re) { "#{$1}#{$2}" }
      
        next if replaced == content
      
        File.binwrite(path, replaced)
        puts "Rewrote refs in: #{path}"
      end
      
      puts "Done"
    end

    def mirror_posts(posts)
      # early return if nothing to do
      if ENV['REMIRROR'] != '1'
        non_cached_post_exists = false
        posts.each do |post|
          next if post.cached?
          non_cached_post_exists = true
          break
        end
        if not non_cached_post_exists
            puts 'all posts cached, skip browser initialization'
            
            if ENV['RESAVE_CACHED_POSTS'] == '1'
              puts 'resaving cached posts'
              posts.each do |post|
                post.re_save_page
              end
            end
            
            return
        end            
      end
      
      # it looks like 8 processes block selenium driver. Use 1 as it works at least
      process_number = 1
      if (process_number_str = ENV['MIRROR_POSTS_PROCESS_NUMBER'])
        process_number = process_number_str.to_i
      end
      
      start_time = Time.now
      limiter = RateLimiter.new(4) # max calls per minute
      
      wget_target_dir_path = "#{out_dir}/#{@username}_files"
      download_artifacts = true # ENV['DOWNLOAD_ARTIFACTS'] == '1'
      
      with_browser do |browser|
        # check if proxy is active
        browser.navigate.to('http://ifconfig.me/ip')
        #puts "public IP address: #{browser.page_source}"
        puts "public IP address: #{Nokogiri::HTML(browser.page_source).at_xpath("/html/body/pre")&.text}"
        
        # To avoid error
        #   invalid cookie domain
        #       (Session info: chrome=154.0.8037.57)
        # add_session_cookie should be called after initial navigation. So do warm up load first
        profile_url = get_journal_url + "/profile/"
        puts "warm up browser user data, loading #{profile_url}"
        browser.navigate.to(profile_url)
        add_session_cookie(browser)
      
        puts 'wait for 15 seconds to avoid LJ throttling'
        sleep 15
        
        #Parallel.each(posts, in_processes: process_number, progress: "Mirroring #{posts.size} HTMLs") do |post|
        posts.each do |post|
          next if post.cached? && ENV['REMIRROR'] != '1'
          
          elapsed_time_seconds = (Time.now - start_time)  
          et_h = (elapsed_time_seconds / 3600).to_i
          et_m = (elapsed_time_seconds / 60).to_i % 60
          et_s = elapsed_time_seconds.to_i % 60
          puts "Will mirror #{post}. Time: #{'%02d' % et_h}:#{'%02d' % et_m}:#{'%02d' % et_s}"
          
          begin
            limiter.call do 
              post.mirror(browser, download_artifacts)
            end
          rescue => e
            puts e
            retry
          end
          
          #if download_artifacts
          #  puts 'post process wget artifacts after post downloading'
          #  ungzip_css(wget_target_dir_path, ['css', 'html'])
          #end
        end
      end
      
      if download_artifacts
        puts 'post process wget artifacts ONCE'
        # do it only once after downloading because doing it on the per post basis affect speed
        # as number of files to upgrade is growing and it decreases process speed.
        ungzip_css(wget_target_dir_path, ['css', 'html'])
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

      #puts "after preparation"
      #`pgrep -l chrome`

      yield browser
      ensure
        #puts "before quit"
        #`pgrep -l chrome`
        begin
          if not browser.nil?
            puts "quitting browser"
            browser.quit
            puts "sleep 3 sec"
            sleep 3 ###!!!
          end
        rescue => e1
          puts "Browser quitting error:"
          puts e1.inspect
          puts e1.backtrace
          raise e1
      end
    end

    def get_date_range
      start_year = 2011
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
      html.css('.sidebar')&.remove
      urls = html.css('a').select { |a| a.attribute('href')&.value =~ %r{://#{@username}.livejournal.com/\d+.html} }.map { |a| a.attribute('href').value }
      putsd "    #{urls.size} for #{year}.#{month}"
      return urls.map { |u| RemotePost.new(u.strip, blog: self) }
    end
  end
end
