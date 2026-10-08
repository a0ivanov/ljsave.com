def putsd(*args)
  if ENV['DEBUG_LOG'] == '1'
    puts args
  end
end

OPERA_USERAGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36'

def read_url(url, opts: {})
  require 'open-uri'
  # require 'resolv-replace'
  
  #if (proxy = ENV['PROXY'])
  #  proxy = "http://#{proxy}" unless proxy.start_with?('http://')
  #  opts[:proxy] = URI.parse(proxy)
  #  opts['User-Agent'] = OPERA_USERAGENT
  #  #opts[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_NONE
  #  #opts[:ssl_min_version] = :TLSv1_2
  #  #opts[:open_timeout] = 60
  #  #opts[:read_timeout] = 60
  #end
  
  if (url.include? ".livejournal.com/")
    if (lj_proxy = ENV['LJ_HTTP_HTTPS_PROXY'])
        lj_proxy = "http://#{lj_proxy}" unless lj_proxy.start_with?('http://')
        opts[:proxy] = URI.parse(lj_proxy)
        opts['User-Agent'] = OPERA_USERAGENT
        
        #putsd("read_url: replacing protocol to http for lj proxy")
        url = url.sub! 'https://', 'http://' # lj proxy will restore it.
    end
  end

  #test_query = URI.open('https://realityresearcher.ru', opts).read
  #putsd("test_query: #{test_query}")

  #putsd("read_url: #{url}")
  return URI.open(url, opts).read
end
