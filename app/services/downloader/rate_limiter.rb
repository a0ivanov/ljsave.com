module Downloader
  # Made by Deepseek
  class RateLimiter
    def initialize(max_calls_per_minute)
      @max_calls = max_calls_per_minute
      @interval = 60.0 / max_calls_per_minute
      @last_call = 0
    end
  
    def call
      now = Time.now.to_f
      wait_time = @interval - (now - @last_call)
      
      if wait_time > 0
        puts "Wait for #{wait_time} seconds"
        sleep(wait_time)
      end
      
      @last_call = Time.now.to_f
      yield
    end
  end
end