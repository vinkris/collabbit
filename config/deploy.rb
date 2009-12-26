require 'erb'
require 'yaml'

settings = YAML.load_file('deploy.yml')

set :application, "collabbit"
set :repository,  settings[:repository]
set :deploy_to,   settings[:deploy_to]

set :scm,         :git
set :branch,      settings[:branch]

set :domain,      settings[:domain]
set :user,        settings[:user]
set :use_sudo,    false

set :deploy_via, :remote_cache
# set :git_shallow_clone, 1

role :app, domain
role :web, domain
role :db,  domain, :primary => true

ssh_options[:paranoid] = false
default_run_options[:pty] = true

before "deploy:setup", :db
after "deploy:update_code", "db:symlink"

before "deploy:setup", :mail
after "deploy:update_code", "mail:symlink"
  
namespace :passenger do

  desc <<-DESC
    Restarts your application. \
    This works by creating an empty `restart.txt` file in the `tmp` folder
    as requested by Passenger server.
  DESC
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{current_path}/tmp/restart.txt"
  end
  
  desc <<-DESC
    Starts the application servers. \
    Please note that this task is not supported by Passenger server.
  DESC
  task :start, :roles => :app do
    logger.info ":start task not supported by Passenger server"
  end
  
  desc <<-DESC
    Stops the application servers. \
    Please note that this task is not supported by Passenger server.
  DESC
  task :stop, :roles => :app do
    logger.info ":stop task not supported by Passenger server"
  end

end


namespace :deploy do

  desc <<-DESC
    Restarts your application. \
    Overwrites default :restart task for Passenger server.
  DESC
  task :restart, :roles => :app, :except => { :no_release => true } do
    passenger.restart
  end
  
  desc <<-DESC
    Starts the application servers. \
    Overwrites default :start task for Passenger server.
  DESC
  task :start, :roles => :app do
    passenger.start
  end
  
  desc <<-DESC
    Stops the application servers. \
    Overwrites default :start task for Passenger server.
  DESC
  task :stop, :roles => :app do
    passenger.stop
  end
end

namespace :db do
  desc "Create database yaml in shared path" 
  task :default do
    set :db_user do
      Capistrano::CLI.ui.ask 'Email Address: '
    end
    set :db_pass do
     Capistrano::CLI.password_prompt 'Database Password: '
    end
    db_config = ERB.new <<-EOF
    production:
      database: #{application}_prod
      adapter: mysql
      encoding: utf8
      username: #{db_user}
      password: #{db_pass}
    EOF

    run "mkdir -p #{shared_path}/config" 
    put db_config.result, "#{shared_path}/config/database.yml" 
  end

  desc "Make symlink for database yaml" 
  task :symlink do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml" 
  end
end

namespace :mail do
  desc "Create mailserver yaml in shared path" 
  task :default do
    
    set :email_addr do
      Capistrano::CLI.ui.ask 'Email Address: '
    end
    set :email_pass do
      Capistrano::CLI.password_prompt 'Email Password: '
    end
    
    smtp_settings = ERB.new <<-EOF
    ActionMailer::Base.smtp_settings = {
      :enable_starttls_auto => true,
      :address        => 'smtp.gmail.com',
      :port           => 587,
      :domain         => 'collabbit.org',
      :authentication => :plain,
      :user_name      => '#{email_addr}',
      :password       => '#{email_pass}'
    }
    EOF

    run "mkdir -p #{shared_path}/config/initializers" 
    put smtp_settings.result, "#{shared_path}/config/initializers/smtp_settings.rb"
  end

  desc "Make symlink for database yaml" 
  task :symlink do
    run "ln -nfs #{shared_path}/config/initializers/smtp_settings.rb #{release_path}/config/initializers/smtp_settings.rb" 
  end
end
