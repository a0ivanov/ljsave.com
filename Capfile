require 'recap/recipes/rails'

set :repository, 'git@github.com:mgz/ljsave.com.git'

set :application, 'ljsave.com'
server 'ljsave_deploy_host', :app

before 'rails:db:migrate', :copy_overlays

namespace :deploy do
  task :restart do
    as_app 'mkdir -p tmp; touch tmp/restart.txt'
    make_tag
  end
end

task :copy_overlays do
  as_app 'if [ -d ../overlay ]; then rsync -q -a --no-perms --no-owner --no-group -I --no-times  ../overlay/ ./; fi'
end

task :update_crontab do
  as_app 'bundle exec whenever --update-crontab'
end

task :make_tag do
  `git tag deploy/#{application}/#{Time.now.strftime('%Y/%m/%d_%H-%M')} #{branch}`
end
