# frozen_string_literal: true

require 'rake'

require 'capistrano/dsl/new_artrails_capistrano_paths'
require 'capistrano/new_artrails_capistrano/helpers'

include Capistrano::NewArtrailsCapistrano::Helpers
include Capistrano::DSL::NewArtrailsCapistranoPaths

# remote_cache = lambda do
#   cache = fetch(:remote_cache)
#   cache = deploy_to + '/' + cache if cache && cache !~ /^\//
#   cache
# end

namespace :load do
  task :defaults do
    set :process_owner_user, -> { process_owner_user }
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

    # set :remote_cache,  "shared/rsync"
    set :remote_cache, -> { new_artrails_capistrano_remote_cache }
    set :front_remote_cache, -> { new_artrails_capistrano_front_remote_cache }
    # aka repository_cache

    # do lokalnych adresow dostajemy sie bez proxy
    set :proxy_host, nil # "proxy.non.3dart.com"
    set :proxy_port, nil # "3128"
  end
end

# https://github.com/capistrano-plugins/capistrano-safe-deploy-to/blob/master/lib/capistrano/tasks/safe_deploy_to.rake
namespace :new_artrails_capistrano do
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
          system("scp config/#{cf} #{local_user}@#{server}:#{shared_path}/config/#{cf}")
        end
      # end

      # setup pids
      # FIXME: j.w.
      # servers = find_servers_for_task(current_task)
      # servers.each do |server|
        new_artrails_capistrano_run("mkdir -p #{shared_path}/pids")
      # end

      # uprawnienia
      unless dir_exists?(deploy_to)
        new_artrails_capistrano_run "sudo -u mongrel chmod -R g+rw #{deploy_to}"
        new_artrails_capistrano_run "sudo -u mongrel chgrp -R mongrel #{deploy_to}"
      end

      # repository_cache
      unless dir_exists?(repository_cache)
        new_artrails_capistrano_run "pwd && mkdir -p #{shared_path}/#{repository_cache}"
        # new_artrails_capistrano_run "chgrp -R mongrel #{shared_path}/#{repository_cache}"
        # new_artrails_capistrano_run "chmod g+w #{shared_path}/#{repository_cache}"
      end

      # log
      new_artrails_capistrano_run "mkdir -p /var/log/mongrel/#{fetch(:new_artrails_capistrano_log_dir_name)}"
    end
  end













  #-------------------------------------------------
  task :check do
    # nothing to check, but expected by framework
  end

  task :create_cache do
    next if File.directory?(File.expand_path(fetch(:local_cache))) # TODO: check if it's actually our repo instead of assuming
    run_locally do
      execute :git, 'clone', fetch(:repo_url), fetch(:local_cache)
    end
  end

  desc 'stage the repository in a local directory'
  task stage: [:create_cache] do
    run_locally do
      within fetch(:local_cache) do
        execute :git, 'fetch', '--quiet', '--all', '--prune'
        execute :git, 'reset', '--hard', "origin/#{fetch(:branch)}"
      end
    end
  end

  desc 'stage and rsync to the server'
  task sync: [:stage] do
    release_roles(:all).each do |role|
      user = role.user || fetch(:user)
      user += '@' unless user.nil?

      rsync_args = []
      rsync_args.concat fetch(:rsync_options)
      rsync_args.concat fetch(:rsync_include, []).map { |e| "--include #{e}" }
      rsync_args.concat fetch(:rsync_exclude, []).map { |e| "--exclude #{e}" }
      rsync_args << fetch(:local_cache) + '/'
      rsync_args << "#{user}#{role.hostname}:#{remote_cache.call}"

      run_locally do
        execute :rsync, *rsync_args
      end
    end
  end

  desc 'stage, rsync to the server, and copy the code to the releases directory'
  task release: [:sync] do
    copy = %(#{fetch(:copy_command)} "#{remote_cache.call}/" "#{release_path}/")
    on release_roles(:all) do
      execute copy
    end
  end

  task create_release: [:release] do
    # expected by the framework, delegate to better named task
    run "mkdir -p #{fetch :releases_path}"
  end

  task :set_current_revision do
    run_locally do
      set :current_revision, capture(:git, 'rev-parse', fetch(:branch))
    end
  end
end
