module Bot
    def self.expand_all_comments_on_page
        while (span = BROWSER.find_elements(css: '.comment-meta span').detect{|s| s.attribute('id').start_with?('expand_') && s.attribute('style') != 'display: none;'})
            # puts span.attribute('style')
            a = span.find_element(css: 'a')
            comment_id = a.attribute('onclick')[/'(\d+)'/, 1]
            puts "Expanding #{comment_id}..."
            BROWSER.execute_script("arguments[0].click();", a)
            
            wait = Selenium::WebDriver::Wait.new(:timeout => 10)
            wait.until {BROWSER.find_element id: "collapse_#{comment_id}"}
            puts '    Done.'
            sleep 1
        end
        puts 'Everything expanded'
    end
end

