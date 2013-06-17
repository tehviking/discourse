require 'sidekiq/capistrano'
require "bundler/capistrano"
require "rvm/capistrano"

# deploy command: cap -S branch="<branchname>" deploy
set :user, ENV["DEPLOY_USERNAME"]
set :domain, 'community.emberatx.org'
set :application, "dis"

set :repository, "git@github.com:tehviking/discourse.git" # Your clone URL
set :scm, "git"
set :branch, fetch(:branch, "master")
set :scm_verbose, true
set :deploy_via, :remote_cache
set :scm_passphrase, ENV["DEPLOY_PASSWORD"] # The deploy user's password
set :deploy_to, "/home/#{user}/#{domain}"
set :use_sudo, false
set :rvm_ruby_string, 'ruby-1.9.3-p392@discourse'

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

role :web, ENV["LINODE_IP"] # Your HTTP server, Apache/etc
role :app, ENV["LINODE_IP"] # This may be the same as your `Web` server
role :db, ENV["LINODE_IP"], :primary => true # This is where Rails migrations will run

namespace :deploy do
  task :restart_passenger do
    run "touch #{current_path}/tmp/restart.txt"
  end

  desc "Symlink shared configs and folders on each release."
  task :symlink_shared do
    run "ln -nfs #{shared_path}/.env #{release_path}/.env"
    run "ln -nfs #{shared_path}/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/redis.yml #{release_path}/config/redis.yml"
  end

  # Tasks to start/stop/restart thin
  desc 'Start thin servers'
  task :start, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && RUBY_GC_MALLOC_LIMIT=90000000 bundle exec thin -C config/thin.yml start", :pty => false
  end

  desc 'Stop thin servers'
  task :stop, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && bundle exec thin -C config/thin.yml stop"
  end

  desc 'Restart thin servers'
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && RUBY_GC_MALLOC_LIMIT=90000000 bundle exec thin -C config/thin.yml restart"
  end
end

# Tasks to start/stop/restart a daemonized clockwork instance
namespace :clockwork do
  desc "Start clockwork"
  task :start, :roles => [:app] do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec clockworkd -c #{current_path}/config/clock.rb --pid-dir #{shared_path}/pids --log --log-dir #{shared_path}/log start"
  end

  task :stop, :roles => [:app] do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec clockworkd -c #{current_path}/config/clock.rb --pid-dir #{shared_path}/pids --log --log-dir #{shared_path}/log stop"
  end

  task :restart, :roles => [:app] do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec clockworkd -c #{current_path}/config/clock.rb --pid-dir #{shared_path}/pids --log --log-dir #{shared_path}/log restart"
  end
end

after  "deploy:stop",    "clockwork:stop"
after  "deploy:start",   "clockwork:start"
before "deploy:restart", "clockwork:restart"


# Seed your database with the initial production image. Note that the production
# image assumes an empty, unmigrated database.
namespace :db do
  desc 'Seed your database for the first time'
  task :seed do
    run "cd #{current_path} && psql -d discourse_production < pg_dumps/production-image.sql"
  end
end

# Migrate the database with each deployment
after  'deploy:update_code', 'deploy:migrate'

after 'deploy:update_code', 'deploy:symlink_shared'
after "deploy:migrations", "deploy:restart_passenger"
after "deploy:migrations", "deploy:cleanup"
