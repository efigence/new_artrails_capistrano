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
    # http://www.comentum.com/rsync.html # -a --no-p --no-g --delete
    set :copy_command,  "rsync -a --no-p --no-g --delete" # "rsync --archive --acls --xattrs"
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

    set :new_artrails_capistrano_log_dir_name, -> { new_artrails_capistrano_log_dir_name }

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

    set :app_address, nil
  end
end

namespace :artrails do
  desc <<-DESC
    set symlinks for configs logs, set rights and check is it working
  DESC

  namespace :symlink do
    task :config do
      on roles :app, exclude: :no_release do |task|
        # link default configs
        # servers = find_servers_for_task(current_task)
        # servers.each do |server|
        # FIXME:
        server = host
          # config_files.each do |cf|
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
        new_artrails_capistrano_run "ln -s /var/log/#{fetch(:new_artrails_capistrano_sudo_as)}/#{fetch(:new_artrails_capistrano_log_dir_name)}/ #{release_path}/log"
      end
    end

    task :rights do
      on roles :app, exclude: :no_release do
        #new_artrails_capistrano_run( "sudo -i -u #{fetch(:new_artrails_capistrano_sudo_as)} chmod g+w -R #{current_path}" )
        #new_artrails_capistrano_run( "sudo -i -u #{fetch(:new_artrails_capistrano_sudo_as)} chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{current_path}" )
      end
    end
  end

  task :check_is_it_working do
    on roles :app, exclude: :no_release do
      puts "Sleeping 5 seconds..."
      sleep( 5 )
      puts "Asking is it working..."
      if fetch(:app_address).to_s[/8080/]
        proxy_host = nil
        proxy_port = nil
      else
        proxy_host = fetch(:proxy_host)
        proxy_port = fetch(:proxy_port)
      end
      http = Net::HTTP::Proxy(proxy_host, proxy_port).start(*fetch(:app_address).split(':'))
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
      # not for Cap 3
      # on_rollback { new_artrails_capistrano_run "rm #{current_path}/tmp/maintenance.yml" }
      if test "[ -f #{release_path}/config/maintenance.yml ]"
        new_artrails_capistrano_run "cp #{release_path}/config/maintenance.yml #{release_path}/tmp/maintenance.yml"
      end
    end
  end

  desc "Maintenance stop"
  task :off do
    on roles :web do
      new_artrails_capistrano_run "rm -rf #{release_path}/tmp/maintenance.yml"
    end
  end
end

# https://github.com/capistrano-plugins/capistrano-safe-deploy-to/blob/master/lib/capistrano/tasks/safe_deploy_to.rake
namespace :deploy do
  Rake::Task["deploy:set_current_revision"].clear_actions
  desc "Place a REVISION file with the current revision SHA in the current release path"
  task :set_current_revision  do
    on release_roles(:all) do
      # new_artrails_capistrano_run "echo \"#{fetch(:current_revision)}\" >> #{release_path}/REVISION"

      # echo called twice on purpose, because only that way it works...
      cmd =<<-CMD
        sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} bash -c "
        echo '#{fetch(:current_revision)}' > #{release_path}/REVISION &&
        echo -e '#{fetch(:current_revision)}' > #{release_path}/REVISION &&
        chmod g+w -R #{release_path}/REVISION &&
        chgrp #{fetch(:new_artrails_capistrano_sudo_as)} #{release_path}/REVISION
        "
      CMD
      new_artrails_capistrano_run cmd.gsub(/\r?\n/, '').gsub(/\s+/, ' ')

    end
  end
  Rake::Task["deploy:cleanup"].clear_actions
  desc "Clean up old releases"
  task :cleanup do
    on release_roles :all do |host|
      releases = capture(:ls, "-x", releases_path).split
      if !(releases.all? { |e| /^\d{14}$/ =~ e })
        warn t(:skip_cleanup, host: host.to_s)
      elsif releases.count >= fetch(:keep_releases)
        info t(:keeping_releases, host: host.to_s, keep_releases: fetch(:keep_releases), releases: releases.count)
        directories = (releases - releases.last(fetch(:keep_releases)))
        if directories.any?
          directories_str = directories.map do |release|
            releases_path.join(release)
          end.join(" ")
          # execute :rm, "-rf", directories_str
          new_artrails_capistrano_run "rm -rf #{directories_str}" if directories_str.to_s[/\/releases\//]
        else
          info t(:no_old_releases, host: host.to_s, keep_releases: fetch(:keep_releases))
        end
      end
    end
  end
  # namespace :bundler do
  #   task :install do
  #     on fetch(:bundle_servers) do
  #       within release_path do
  #         with fetch(:bundle_env_variables, {}) do
  #           require 'byebug'
  #           byebug
  #         end
  #       end
  #     end
  #   end
  # end
  Rake::Task["deploy:log_revision"].clear_actions
  desc "Log details of the deploy"
  task :log_revision do
    on release_roles(:all) do
      within releases_path do
        # execute :echo, %Q{"#{revision_log_message}" >> #{revision_log}}
        execute :echo, %Q{"#{revision_log_message}" >> #{revision_log}}
        # require 'shellwords'
        # new_artrails_capistrano_run "echo '#{Shellwords.escape(revision_log_message)}' >> #{revision_log}"
        execute :chmod, "g+w #{revision_log}"
      end
    end
  end
  namespace :bundler do
    task :install do
      on fetch(:bundle_servers) do
        within release_path do
          with fetch(:bundle_env_variables, {}) do
            options = []
            options << "--gemfile #{fetch(:bundle_gemfile)}" if fetch(:bundle_gemfile)
            options << "--path #{fetch(:bundle_path)}" if fetch(:bundle_path)
            unless test(:bundle, :check, *options)
              options << "--binstubs #{fetch(:bundle_binstubs)}" if fetch(:bundle_binstubs)
              options << "--jobs #{fetch(:bundle_jobs)}" if fetch(:bundle_jobs)
              options << "--without #{fetch(:bundle_without)}" if fetch(:bundle_without)
              options << "#{fetch(:bundle_flags)}" if fetch(:bundle_flags)
              # execute :bundle, :install, *options
              new_artrails_capistrano_run_with_rvm_in_release_path "bundle install #{options.join(' ')}"
            end
          end
        end
      end
    end

    desc "Remove unused gems installed by bundler"
    task :clean do
      on fetch(:bundle_servers) do
        within release_path do
          with fetch(:bundle_env_variables, {}) do
            # execute :bundle, :clean, fetch(:bundle_clean_options, "")
            new_artrails_capistrano_run "bundle clean #{fetch(:bundle_clean_options, "")}"
          end
        end
      end
    end
  end


  namespace :symlink do
    Rake::Task["deploy:symlink:linked_dirs"].clear
    desc "Symlink linked directories"
    task :linked_dirs do
      next unless any? :linked_dirs
      on release_roles :all do
        # execute :mkdir, "-p", linked_dir_parents(release_path)
        new_artrails_capistrano_run "mkdir -p #{linked_dir_parents(release_path).map(&:to_s).join(' ')}"

        fetch(:linked_dirs).each do |dir|
          target = release_path.join(dir)
          source = shared_path.join(dir)
          next if test "[ -L #{target} ]"
          # execute :rm, "-rf", target if test "[ -d #{target} ]"
          new_artrails_capistrano_run "rm -rf #{target.to_s}" if test "[ -d #{target.to_s} ]"
          # execute :ln, "-s", source, target
          new_artrails_capistrano_run "ln -s #{source.to_s} #{target.to_s}"
        end
      end
    end
    desc "Symlink release to current"
    task :release do
      on release_roles :all do
        # require 'byebug'
        # byebug
        tmp_current_path = release_path.parent.join(current_path.basename)
        # execute :ln, "-s", release_path, tmp_current_path
        new_artrails_capistrano_run "ln -s #{release_path} #{tmp_current_path}"
        # execute :mv, tmp_current_path, current_path.parent
        new_artrails_capistrano_run "mv #{tmp_current_path} #{current_path.parent}"
      end
    end
  end
  namespace :isItWorking do
    task :activate do
      on roles :web, exclude: :no_release do
        new_artrails_capistrano_run "touch #{current_path}/tmp/isItWorking.txt"
      end
    end
    task :deactivate do
      on roles :web, exclude: :no_release do
        new_artrails_capistrano_run "rm -f #{current_path}/tmp/isItWorking.txt"
      end
    end
  end

  desc 'Normalize asset timestamps'
  task :normalize_assets => [:set_rails_env] do
    on release_roles(fetch(:assets_roles)) do
      assets = Array(fetch(:normalize_asset_timestamps, []))
      if assets.any?
        within release_path do
          # execute :find, "#{assets.join(' ')} -exec touch -t #{asset_timestamp} {} ';'; true"
          new_artrails_capistrano_run "find #{assets.join(' ')} -exec touch -t #{asset_timestamp} {} ';'; true"
        end
      end
    end
  end

  desc 'Cleanup expired assets'
  task :cleanup_assets => [:set_rails_env] do
    next unless fetch(:keep_assets)
    on release_roles(fetch(:assets_roles)) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          # execute :rake, "'assets:clean[#{fetch(:keep_assets)}]'"
          new_artrails_capistrano_run "rake 'assets:clean[#{fetch(:keep_assets)}]'"
        end
      end
    end
  end

  desc 'Clobber assets'
  task :clobber_assets => [:set_rails_env] do
    on release_roles(fetch(:assets_roles)) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          # execute :rake, "assets:clobber"
          new_artrails_capistrano_run "rake assets:clobber"
        end
      end
    end
  end

  desc 'Rollback assets'
  task :rollback_assets => [:set_rails_env] do
    begin
      invoke 'deploy:assets:restore_manifest'
    rescue Capistrano::FileNotFound
      invoke 'deploy:compile_assets'
    end
  end

  namespace :assets do
    task :symlink do
      on roles :web, exclude: :no_release do
        cmd =<<-CMD
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} rm -rf #{release_path}/public/#{fetch(:assets_prefix)} &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} mkdir -p #{release_path}/public &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} mkdir -p #{shared_path}/assets &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} ln -s #{shared_path}/assets #{release_path}/public/#{fetch(:assets_prefix)} &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} chmod g+w -R  #{release_path}/public/#{fetch(:assets_prefix)} &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{release_path}/public/#{fetch(:assets_prefix)} &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} chmod g+w -R  #{shared_path}/assets &&
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{shared_path}/assets
        CMD
        new_artrails_capistrano_run cmd.gsub(/\r?\n/, '').gsub(/\s+/, ' ')
      end
    end
    Rake::Task['deploy:assets:backup_manifest'].clear_actions
    task :backup_manifest do
      on release_roles(fetch(:assets_roles)) do
        within release_path do
          backup_path = release_path.join('assets_manifest_backup')

          target = new_artrails_capistrano_detect_manifest_path

          # execute :mkdir, '-p', backup_path
          new_artrails_capistrano_run "mkdir -p #{backup_path}"
          # execute :cp,
          #   detect_manifest_path,
          #   backup_path
          if test "[[ -f #{target} ]]"
            new_artrails_capistrano_run "cp #{target} #{backup_path}"
          else
            msg = 'Rails assets manifest file not found.'
            warn msg
            # FIXME: Rails 5 only
            # fail Capistrano::FileNotFound, msg
          end
        end
      end
    end

    Rake::Task['deploy:assets:restore_manifest'].clear_actions
    task :restore_manifest do
      on release_roles(fetch(:assets_roles)) do
        within release_path do
          target = new_artrails_capistrano_detect_manifest_path
          source = release_path.join('assets_manifest_backup', File.basename(target))
          if test "[[ -f #{source} && -f #{target} ]]"
            # execute :cp, source, target
            new_artrails_capistrano_run "cp #{source} #{target}"
          else
            msg = 'Rails assets manifest file (or backup file) not found.'
            warn msg
            # FIXME: Rails 5 only
            # fail Capistrano::FileNotFound, msg
          end
        end
      end
    end

    # TODO: https://github.com/capistrano/rails/blob/master/lib/capistrano/tasks/assets.rake

    # https://github.com/capistrano/rails/blob/f4befc4edc8b287e2317ccd1150c793fe337eebb/lib/capistrano/tasks/assets.rake#L64
    Rake::Task['deploy:assets:precompile'].clear_actions
    task :precompile do
      on release_roles(fetch(:assets_roles)) do
        within release_path do
          with rails_env: fetch(:rails_env), rails_groups: fetch(:rails_assets_groups) do
            # execute :rake, "assets:precompile"
            # require 'byebug'
            # byebug
            cmd =<<-CMD
              sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} sh -c "
              source\\\\ '/usr/local/rvm/scripts/rvm' &&
              cd #{fetch(:latest_release_directory)} &&
              RAILS_ENV=#{fetch(:rails_env)} #{fetch(:asset_env)} #{rake} assets:precompile &&
              chmod g+w -R  #{shared_path}/assets &&
              chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{shared_path}/assets
              "
            CMD
            new_artrails_capistrano_run cmd.gsub(/\r?\n/, '').gsub(/\s+/, ' ')
          end
        end
      end
    end
    # task :precompile do
    #   on roles :web, exclude: :no_release do
    #     cmd =<<-CMD
    #       sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} sh -c "
    #       source\\\\ '/usr/local/rvm/scripts/rvm' &&
    #       cd #{fetch(:latest_release_directory)} &&
    #       RAILS_ENV=#{fetch(:rails_env)} #{fetch(:asset_env)} #{rake} assets:precompile &&
    #       chmod g+w -R  #{shared_path}/assets &&
    #       chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{shared_path}/assets
    #       "
    #     CMD
    #     new_artrails_capistrano_run cmd.gsub(/\r?\n/, '').gsub(/\s+/, ' ')
    #   end
    # end
    # task :clean do
    #   on roles :web, exclude: :no_release do
    #     cmd =<<-CMD
    #       sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} sh -c "
    #       source '/usr/local/rvm/scripts/rvm' &&
    #       cd #{fetch(:latest_release_directory)} &&
    #       RAILS_ENV=#{fetch(:rails_env)} #{fetch(:asset_env)} #{rake} assets:clean &&
    #       chmod g+w -R  #{shared_path}/assets &&
    #       chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{shared_path}/assets
    #       "
    #     CMD
    #     new_artrails_capistrano_run cmd.gsub(/\r?\n/, '').gsub(/\s+/, ' ')
    #   end
    # end
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

# TODO # FIXME: override
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
          if file_exists?("#{shared_path}/config/#{cf}")
            puts "Skip. File exists: #{shared_path}/config/#{cf}"
          else
            new_artrails_capistrano_run("touch #{shared_path}/config/#{cf}")
            new_artrails_capistrano_run("chmod g+rw #{shared_path}/config/#{cf}")
            cf_path = "#{local_user}@#{server}:#{shared_path}/config/#{cf}"
            puts "scp config/#{cf} #{cf_path}"
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
      #unless dir_exists?(deploy_to)
        if revision_log.to_s[/\.log\z/]
          new_artrails_capistrano_run "pwd && rm -rf #{revision_log}" # don't reject command below
        end
        if repository_cache.to_s[/cached\-copy\-/]
          new_artrails_capistrano_run "pwd && rm -rf #{deploy_to}/#{repository_cache}" # don't reject command below
        end
        new_artrails_capistrano_run "sudo -u #{fetch(:new_artrails_capistrano_sudo_as)} chmod -R g+rw #{deploy_to}"
        new_artrails_capistrano_run "sudo -u #{fetch(:new_artrails_capistrano_sudo_as)} chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{deploy_to}"
      #end

      # repository_cache
      unless file_exists?("#{deploy_to}/#{repository_cache}")
        new_artrails_capistrano_run "sudo -u #{fetch(:new_artrails_capistrano_sudo_as)} chmod g+w -R #{shared_path}"
        new_artrails_capistrano_run "pwd && mkdir -p #{deploy_to}/#{repository_cache}"
        new_artrails_capistrano_run "chgrp -R #{fetch(:new_artrails_capistrano_sudo_as)} #{deploy_to}/#{repository_cache}"
        new_artrails_capistrano_run "chmod g+w #{deploy_to}/#{repository_cache}"
      end

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

        # Step 4: Copy the remote cache into place.
        on roles(:app) do
          # instead of set_current_revision
          # too early to do that
          # new_artrails_capistrano_run("echo #{fetch(:current_revision)} > #{release_path}/REVISION")

          new_artrails_capistrano_run( "chmod +r+w+x -R #{remote_cache.call}" ) # HACK (dopisane)
          new_artrails_capistrano_run( "chmod g+w -R #{remote_cache.call}" ) # HACK (dopisane)
          new_artrails_capistrano_run( "chgrp -R mongrel #{remote_cache.call}" ) # HACK (dopisane)

          # instead of copy_command
          # new_artrails_capistrano_run("rsync -a --delete #{remote_cache.call}/ #{release_path}/")
        end
      end
    end

    desc "stage, rsync to the server, and copy the code to the releases directory"
    task :release => [ :sync ] do
      copy = %(#{fetch(:copy_command)} "#{remote_cache.call}/" "#{release_path}/")
      on release_roles(:all) do
        # execute copy
        new_artrails_capistrano_run copy
        # puts 'Doing nothing'
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
        run_locally do
          set :current_revision, capture(:git, 'rev-parse', fetch(:branch))
        end
      end
    end
  end













  # #-------------------------------------------------
  # task :check do
  #   # legacy
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
  #   legacy
  #   run_locally do
  #     set :current_revision, capture(:git, 'rev-parse', fetch(:branch))
  #   end
  # end
end

# hooks
# -----------------------------------------------------------------------------------------------------------------------------------
# before 'deploy:finalize_update', 'deploy:assets:symlink'
# nowe
after 'deploy:publishing', 'deploy:restart'

before 'deploy:updated', 'deploy:assets:symlink'
# before "deploy:updated",  "maintenance:on" # maintenance for current version
before "deploy:restart",      "maintenance:on" # maintenance for new version

after "deploy:updated",      "artrails:symlink:config"
after "deploy:updated",      "artrails:symlink:uploads"

# after "deploy:updated",      "deploy:cleanup"

after "deploy:symlink:release",   "artrails:symlink:log"
after "deploy:symlink:release",   "artrails:symlink:rights"

after "maintenance:on", "deploy:isItWorking:deactivate"
after "maintenance:off", "deploy:isItWorking:activate"
after "maintenance:off", "artrails:check_is_it_working"
