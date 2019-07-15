require 'nokogiri'
require 'open-uri'
require 'parallel'

class User
    attr_reader :username
    
    def initialize(username)
        @username = username
    end

    def get_date_range
        start_year = 2001
        start_year = 2018
        start_month = 1
        
        end_year = Date.today.year
        end_month = Date.today.month
        
        return start_year, start_month, end_year, end_month
        
        # "https://www.livejournal.com/view/?type=month&user=#{@username}&y=$year&m=$month"
    end
    
    def get_post_urls
        post_urls = []
        start_year, start_month, end_year, end_month = get_date_range
        
        years_and_months = []
        
        (start_year..end_year).each do |year|
            (1..12).each do |month|
                next if year == end_year && month > end_month
                years_and_months << [year, month]
            end
        end
        
        results = Parallel.map(years_and_months, in_threads: 16) do |year, month|
            # puts "Now at #{year}.#{month}"
            get_post_urls_from_archive_page(year, month)
        end
        
        return results.compact.flatten
    end
    
    def get_post_urls_from_archive_page(year, month)
        html = Nokogiri::HTML(open("https://#{@username}.livejournal.com/#{year}/#{sprintf('%02d', month)}/"))
        urls =  html.css('.viewsubjects a').map{|a| a.attribute('href').value}
        # puts "    #{urls.size} for #{year}.#{month}"
        return urls
    end

    def load_assets
        http_port = 5011
        http_server_thread = Process.spawn "cd out/#{@username} && ruby -run -e httpd . -p #{http_port}", pgroup: true
        sleep 3
        
        Parallel.each(Dir.glob("out/#{@username}/*.html"), in_processes: 4) do |html_file|
        
         # do |html_file|
            url = "http://localhost:#{http_port}/#{File.basename(html_file)}"
            puts url
            `wget -q -P out/#{@username}/out -nv --page-requisites --no-cookies --no-host-directories --span-hosts -E --wait=0 --execute="robots = off"  --convert-links #{url}`
        end
        
        Process.kill(9, -Process.getpgid(http_server_thread))

    end
end