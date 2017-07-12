# frozen_string_literal: true

require 'rake'

require 'capistrano/dsl/new_artrails_capistrano_paths'
require 'capistrano/new_artrails_capistrano/helpers'

include Capistrano::NewArtrailsCapistrano::Helpers
include Capistrano::DSL::NewArtrailsCapistranoPaths

remote_cache = lambda do
  cache = fetch(:remote_cache) || 'shared/cached-copy-deploy'
  cache = deploy_to + '/' + cache if cache && cache !~ /^\//
  cache
end

namespace :load do
  task :defaults do
    set :new_artrails_capistrano_sudo_as, -> { new_artrails_capistrano_sudo_as }
    # rsync
    if RUBY_PLATFORM =~ /mswin|mingw/
      set :rsync_options, '-az --delete --exclude=\'.git*\' --exclude=\'.rvmrc\' --exclude=\'vendor/bundle\' --exclude=\'doc\' --delete-excluded -e "ssh -i C:\\keys\\openssh-private-key.pub"'
    else # linux, mac
      set :rsync_exclude, %w[.git* .rvmrc* vendor/bundle doc]
      set :rsync_options, %w[-az --delete --delete-excluded]
    end
    set :rsync_include, %w[]
    set :copy_command,  "rsync --archive --acls --xattrs"
    set :local_cache,   '.rsync_cache' # ".rsync_cache-#{fetch(:stage)}"
    set :front_local_cache, '.front_rsync_cache' # ".front_rsync_cache-#{fetch(:stage)}"

    set :repo_url, File.expand_path('.')

    # :auto (default): just tries to find the correct path. ~/.rvm wins over /usr/local/rvm
    # :system: defines the RVM path to /usr/local/rvm
    # :user: defines the RVM path to ~/.rvm
    # deploy.rb or stage file (staging.rb, production.rb or else)
    set :rvm_type, :system               # Defaults to: :auto
    set :rvm_ruby_version, :default      # Defaults to: 'default'
    # set :rvm_custom_path, '~/.myveryownrvm'  # only needed if not detected

    set :log_path, nil

    set :ssh_options, {
      keys: %w(/home/#{user}/.ssh/id_rsa),
      auth_methods: %w(publickey password)
    }

    set :asset_env, "RAILS_GROUPS=assets"
    set :assets_prefix, "assets"

    set :use_sudo, false

    # set :remote_cache,  'shared/cached-copy-eploy'
    set :remote_cache, -> { new_artrails_capistrano_remote_cache }
    set :front_remote_cache, -> { new_artrails_capistrano_front_remote_cache }
    # aka repository_cache

    # do lokalnych adresow dostajemy sie bez proxy
    set :proxy_host, nil # "proxy.non.3dart.com"
    set :proxy_port, nil # "3128"
  end
end

namespace :artrails do
  desc <<-DESC
    set symlinks for configs logs, set rights and check is it working
  DESC

  namespace :symlink do
    task :config do
      on roles :app do
        # link default configs
        # FIXME:
        # servers = find_servers_for_task(current_task)
        # servers.each do |server|
        # server = host
          fetch(:new_artrails_capistrano_config_files).each do |cf|
            new_artrails_capistrano_run "ln -fs #{shared_path}/config/#{cf} #{release_path}/config/#{cf}"
          end
        # end
      end
    end

    task :uploads do
      on roles :app, exclude: :no_release do
        new_artrails_capistrano_run "rm -rf #{release_path}/db/uploads"
        new_artrails_capistrano_run "ln -s #{shared_path}/db/uploads #{release_path}/db/uploads"
        new_artrails_capistrano_run "mkdir -p #{shared_path}/db/uploads/simple_captcha"
      end
    end

    task :log do
      on roles :app, exclude: :no_release do
        new_artrails_capistrano_run "rm -rf #{release_path}/log"
        new_artrails_capistrano_run "ln -s /var/log/#{fetch(:new_artrails_capistrano_sudo_as)}/#{log_path || application}/ #{release_path}/log"
      end
    end

    task :rights do
      on roles :app, exclude: :no_release do
        new_artrails_capistrano_run( "sudo -i -u #{fetch(:new_artrails_capistrano_sudo_as)} chmod g+w -R #{current_path}" )
        new_artrails_capistrano_run( "sudo -i -u #{fetch(:new_artrails_capistrano_sudo_as)} chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{current_path}" )
      end
    end
  end

  task :check_is_it_working do
    on roles :app, exclude: :no_release do
      puts "Sleeping 4 seconds..."
      sleep( 3 )
      puts "Asking is it working..."
      http = Net::HTTP::Proxy(proxy_host, proxy_port).start(*app_address.split(':'))
      path='/isItWorking'
      resp, data = http.get(path)
      puts "#{resp.code} #{resp.message} : #{data}"
    end
  end

  task :tailf do
    log_file = "#{current_path}/log/production.log"
    new_artrails_capistrano_run "tail -f #{log_file}" do |channel, stream, data|
      puts data if stream == :out
      if stream == :err
        puts "[Error: #{channel[:host]}] #{data}"
        break
      end
    end
  end
end

namespace :maintenance do
  desc "Maintenance start"
  task :on do
    on roles :web do
      on_rollback { run "rm #{current_path}/tmp/maintenance.yml" }
      page = File.read("config/maintenance.yml")
      put page, "#{current_path}/tmp/maintenance.yml"
      new_artrails_capistrano_run "chmod g+w #{current_path}/tmp/maintenance.yml"
    end
  end

  desc "Maintenance stop"
  task :off do
    on roles :web do
      new_artrails_capistrano_run "rm #{latest_release}/tmp/maintenance.yml"
    end
  end
end

# https://github.com/capistrano-plugins/capistrano-safe-deploy-to/blob/master/lib/capistrano/tasks/safe_deploy_to.rake
namespace :deploy do
  namespace :bundler do
    task :install do
      on fetch(:bundle_servers) do
        within release_path do
          with fetch(:bundle_env_variables, {}) do
            require 'byebug'
            byebug
            # set :rails_env, :staging
            fetch(:rails_env)
            end
          end
        end
      end
    end
  end
  namespace :isItWorking do
    task :activate do
      on roles :web, exclude: :no_release do
        new_artrails_capistrano_run "sudo -u #{fetch(:new_artrails_capistrano_sudo_as)} touch #{current_path}/tmp/isItWorking.txt"
      end
    end
    task :deactivate do
      on roles :web, exclude: :no_release do
        new_artrails_capistrano_run "sudo -u #{fetch(:new_artrails_capistrano_sudo_as)} rm #{current_path}/tmp/isItWorking.txt"
      end
    end
  end
  namespace :assets do
    task :symlink do
      on roles :web, exclude: :no_release do
        cmd =<<-CMD
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} rm -rf #{release_path}/public/#{assets_prefix} &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} mkdir -p #{release_path}/public &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} mkdir -p #{shared_path}/assets &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} ln -s #{shared_path}/assets #{release_path}/public/#{assets_prefix} &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} chmod g+w -R  #{release_path}/public/#{assets_prefix} &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{release_path}/public/#{assets_prefix} &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} chmod g+w -R  #{shared_path}/assets &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{shared_path}/assets
        CMD
        new_artrails_capistrano_run cmd.gsub(/\r?\n/, '').gsub(/\s+/, ' ')
      end
    end
    task :precompile do
      on roles :web, exclude: :no_release do
        cmd =<<-CMD
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} sh -c "
          source\\\\ '/usr/local/rvm/scripts/rvm' &&
          cd #{latest_release} &&
          RAILS_ENV=#{rails_env} #{asset_env} #{rake} assets:precompile &&
          chmod g+w -R  #{shared_path}/assets &&
          chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{shared_path}/assets
          "
        CMD
        new_artrails_capistrano_run cmd.gsub(/\r?\n/, '').gsub(/\s+/, ' ')
      end
    end
    task :clean do
      on roles :web, exclude: :no_release do
        cmd =<<-CMD
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} sh -c "
          source '/usr/local/rvm/scripts/rvm' &&
          cd #{latest_release} &&
          RAILS_ENV=#{rails_env} #{asset_env} #{rake} assets:clean &&
          chmod g+w -R  #{shared_path}/assets &&
          chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{shared_path}/assets
          "
        CMD
        new_artrails_capistrano_run cmd.gsub(/\r?\n/, '').gsub(/\s+/, ' ')
      end
    end
  end
  task :start do
    on roles :app do
      new_artrails_capistrano_run "nohup #{current_path}/script/production start"
    end
  end

  task :stop do
    on roles :app do
      new_artrails_capistrano_run "nohup #{current_path}/script/production stop"
    end
  end

  task :restart do
    on roles :app, exclude: :no_release do
      # restart passengera
      new_artrails_capistrano_run "nohup #{current_path}/script/production restart"
    end
  end

  task :setup do # |task|
    on roles :app, exclude: :no_release do
      # setup directories
      dirs = [deploy_to, releases_path, shared_path]
      # https://stackoverflow.com/a/4380894
      # FIXME: undefined
      # shared_children = %w(public/system log tmp/pids)
      # dirs += shared_children.map { |d| File.join(shared_path, d) }
      dirs += fetch(:linked_dirs).map { |d| File.join(shared_path, d) }
      new_artrails_capistrano_run "mkdir -p #{dirs.join(' ')}"

      # setup default configs

      # FIXME: undefined
      # current_task = task.name_with_args
      #require 'byebug'
      #byebug
      # FIXME:
      # servers = find_servers_for_task(current_task)
      # servers.each do |server|
      server = host
        # FIXME:
        # config_files.each do |cf|
        fetch(:new_artrails_capistrano_config_files).each do |cf|
          new_artrails_capistrano_run("mkdir -p #{shared_path}/config")
          new_artrails_capistrano_run("touch #{shared_path}/config/#{cf}")
          new_artrails_capistrano_run("chmod g+rw #{shared_path}/config/#{cf}")
          cf_path = "#{local_user}@#{server}:#{shared_path}/config/#{cf}"
          if file_exists?(cf_path)
            puts "Skip. File exists: #{cf_path}"
          else
            system("scp config/#{cf} #{cf_path}")
          end
        end
      # end

      # setup pids
      # FIXME: j.w.
      # servers = find_servers_for_task(current_task)
      # servers.each do |server|
        new_artrails_capistrano_run("mkdir -p #{shared_path}/pids")
      # end

      # uprawnienia
      new_artrails_capistrano_run "sudo -u #{fetch(:new_artrails_capistrano_sudo_as)} chmod -R g+rw #{deploy_to}"
      new_artrails_capistrano_run "sudo -u #{fetch(:new_artrails_capistrano_sudo_as)} chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{deploy_to}"

      # repository_cache
      new_artrails_capistrano_run "pwd && rm -rf #{deploy_to}/#{repository_cache}"
      new_artrails_capistrano_run "pwd && mkdir #{deploy_to}/#{repository_cache}"
      new_artrails_capistrano_run "chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{deploy_to}/#{repository_cache}"
      new_artrails_capistrano_run "chmod g+w #{deploy_to}/#{repository_cache}"

      # log
      new_artrails_capistrano_run "mkdir -p /var/log/#{fetch(:new_artrails_capistrano_sudo_as)}/#{fetch(:new_artrails_capistrano_log_dir_name)}"
    end
  end







  namespace :git do
    desc "Upload the git wrapper script, this script guarantees that we can script git without getting an interactive prompt"
    task :wrapper do
      on release_roles :all do
        puts "Doing nothing"
        # execute :mkdir, "-p", File.dirname(fetch(:git_wrapper_path)).shellescape
        # upload! StringIO.new("#!/bin/sh -e\nexec /usr/bin/ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no \"$@\"\n"), fetch(:git_wrapper_path)
        # execute :chmod, "700", fetch(:git_wrapper_path).shellescape
      end
    end

    desc "Check that the repository is reachable"
    task check: :'git:wrapper' do
      fetch(:branch)
      on release_roles :all do
        puts "Doing nothing"
        # with fetch(:git_environmental_variables) do
        #   git_plugin.check_repo_is_reachable
        # end
      end
    end

    desc "Clone the repo to the cache"
    task clone: :'git:wrapper' do
      on release_roles :all do
        puts "Doing nothing"
        # if git_plugin.repo_mirror_exists?
        #   info t(:mirror_exists, at: repo_path)
        # else
        #   within deploy_path do
        #     with fetch(:git_environmental_variables) do
        #       git_plugin.clone_repo
        #     end
        #   end
        # end
      end
    end

    desc "Update the repo mirror to reflect the origin state"
    task update: :'git:clone' do
      on release_roles :all do
        puts "Doing nothing"
        # within repo_path do
        #   with fetch(:git_environmental_variables) do
        #     git_plugin.update_mirror
        #   end
        # end
      end
    end

    task :create_cache do
      next if File.directory?(File.expand_path(fetch(:local_cache)))  # TODO: check if it's actually our repo instead of assuming
      run_locally do
        execute :git, 'clone', fetch(:repo_url), fetch(:local_cache)
      end
    end

    desc "stage the repository in a local directory"
    task :stage => [ :create_cache ] do
      run_locally do
        within fetch(:local_cache) do
          execute :git, "fetch", "--quiet", "--all", "--prune"
          execute :git, "reset", "--hard", "origin/#{fetch(:branch)}"
        end
      end
    end

    desc "stage and rsync to the server"
    task :sync => [ :stage ] do
      release_roles(:all).each do |role|

        user = role.user || fetch(:user)
        user = user + "@" unless user.nil?

        rsync_args = []
        rsync_args.concat fetch(:rsync_options)
        rsync_args.concat fetch(:rsync_include, []).map{|e| "--include #{e}"}
        rsync_args.concat fetch(:rsync_exclude, []).map{|e| "--exclude #{e}"}
        rsync_args << fetch(:local_cache) + "/"
        rsync_args << "#{user}#{role.hostname}:#{remote_cache.call}"

        run_locally do
          execute :rsync, *rsync_args
        end
      end
    end

    desc "stage, rsync to the server, and copy the code to the releases directory"
    task :release => [ :sync ] do
      copy = %(#{fetch(:copy_command)} "#{remote_cache.call}/" "#{release_path}/")
      on release_roles(:all) do
        execute copy
      end
    end

    desc "Copy repo to releases"
    # task create_release: :'git:update' do
    #   on release_roles :all do
    #     with fetch(:git_environmental_variables) do
    #       within repo_path do
    #         execute :mkdir, "-p", release_path
    #         git_plugin.archive_to_release_path
    #       end
    #     end
    #   end
    # end
    task create_release: [:release] do
      # expected by the framework, delegate to better named task
      # run "mkdir -p #{fetch :releases_path}"
    end

    desc "Determine the revision that will be deployed"
    # task :set_current_revision do
    #   on release_roles :all do
    #     within repo_path do
    #       with fetch(:git_environmental_variables) do
    #         set :current_revision, git_plugin.fetch_revision
    #       end
    #     end
    #   end
    # end
    task :set_current_revision do
      run_locally do
        set :current_revision, capture(:git, 'rev-parse', fetch(:branch))
      end
    end
  end

















  # #-------------------------------------------------
  # task :check do
  #   # nothing to check, but expected by framework
  # end
  #
  # task :create_cache do
  #   next if File.directory?(File.expand_path(fetch(:local_cache))) # TODO: check if it's actually our repo instead of assuming
  #   run_locally do
  #     execute :git, 'clone', fetch(:repo_url), fetch(:local_cache)
  #   end
  # end
  #
  # desc 'stage the repository in a local directory'
  # task stage: [:create_cache] do
  #   run_locally do
  #     within fetch(:local_cache) do
  #       execute :git, 'fetch', '--quiet', '--all', '--prune'
  #       execute :git, 'reset', '--hard', "origin/#{fetch(:branch)}"
  #     end
  #   end
  # end
  #
  # desc 'stage and rsync to the server'
  # task sync: [:stage] do
  #   release_roles(:all).each do |role|
  #     user = role.user || fetch(:user)
  #     user += '@' unless user.nil?
  #
  #     rsync_args = []
  #     rsync_args.concat fetch(:rsync_options)
  #     rsync_args.concat fetch(:rsync_include, []).map { |e| "--include #{e}" }
  #     rsync_args.concat fetch(:rsync_exclude, []).map { |e| "--exclude #{e}" }
  #     rsync_args << fetch(:local_cache) + '/'
  #     rsync_args << "#{user}#{role.hostname}:#{remote_cache.call}"
  #
  #     run_locally do
  #       execute :rsync, *rsync_args
  #     end
  #   end
  # end
  #
  # desc 'stage, rsync to the server, and copy the code to the releases directory'
  # task release: [:sync] do
  #   copy = %(#{fetch(:copy_command)} "#{remote_cache.call}/" "#{release_path}/")
  #   on release_roles(:all) do
  #     execute copy
  #   end
  # end
  #
  # task create_release: [:release] do
  #   # expected by the framework, delegate to better named task
  #   # run "mkdir -p #{fetch :releases_path}"
  # end
  #
  # task :set_current_revision do
  #   run_locally do
  #     set :current_revision, capture(:git, 'rev-parse', fetch(:branch))
  #   end
  # end
end

# hooks
# -----------------------------------------------------------------------------------------------------------------------------------
# before 'deploy:finalize_update', 'deploy:assets:symlink'
# before "deploy:updated",  "maintenance:on" # maintenance for current version
before "deploy:restart",      "maintenance:on" # maintenance for new version

after "deploy:updated",      "artrails:symlink:config"
after "deploy:updated",      "artrails:symlink:uploads"

after "deploy:updated",      "deploy:cleanup"

after "deploy:symlink:release",   "artrails:symlink:log"
after "deploy:symlink:release",   "artrails:symlink:rights"

after "deploy:restart",          "artrails:check_is_it_working"
