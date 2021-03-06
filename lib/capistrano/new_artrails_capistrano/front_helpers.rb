# frozen_string_literal: true

module Capistrano
  module NewArtrailsCapistrano
    module FrontHelpers

      def front_branch
        fetch(:front_branch) || 'master'
      end

      def front_rsync_remote_cache
        fetch(:front_remote_cache) || "shared/front-cached-copy-#{fetch(:local_user) || 'deploy'}"
      end

      def front_local_cache
        front_application = fetch(:front_application)
        # "-#{fetch(:stage)}"
        fetch(:front_local_cache) || "/tmp/.#{front_application}_rsync_cache"
      end

      def front_rsync_credentials
        fetch(:local_user)
      end

      def front_dist_dir_name
        fetch(:front_dist_dir_name) || 'dist'
      end

      def front_rsync_options
        fetch(:front_rsync_options) || fetch(:rsync_options)
      end

      def front_rsync_include
        fetch(:front_rsync_include) || fetch(:rsync_include)
      end

      def front_rsync_exclude
        fetch(:front_rsync_exclude) || fetch(:rsync_exclude)
      end

      # do not delete Rails' Apache served folders
      def front_copy_command
        assets_prefix = fetch(:assets_prefix) || 'assets'
        keeps = fetch(:backend_dirs_or_files_to_keep_in_public) || ([assets_prefix] + %w[ images system upload download])
        if keeps.empty?
          keep_string = ''
        else
          keep_string = ' ' + keeps.map { |keep| "--exclude=\'#{keep}\'" }.join(' ').to_s
        end
        "rsync -a --no-p --no-g --delete#{keep_string}"
      end

      def front_revision
        @front_revision ||= `git ls-remote #{fetch(:front_repo_url)} #{front_branch}`.split("\t").first
      end

      def front_release_path
        File.join(release_path, 'public')
      end

      def front_install_command
        fetch(:front_install_command) ||
        <<-CMD
          npm install &&
          bower install &&
          gulp clean &&
          gulp build
        CMD
      end
      def front_sync_command
        fetch(:front_sync_command) ||
        <<-CMD
          cd #{front_local_cache} &&
          git fetch #{fetch(:front_repo_url)} #{front_branch} &&
          git fetch --tags #{fetch(:front_repo_url)} #{front_branch} &&
          git reset --hard #{front_revision} &&
          #{front_install_command}
        CMD
      end

      def front_checkout_command
        fetch(:front_checkout_command) ||
        <<-CMD
          git clone #{fetch(:front_repo_url)} #{front_local_cache} &&
          cd #{front_local_cache} &&
          git checkout -b deploy/#{front_branch} #{front_revision} &&
          #{front_install_command}
        CMD
      end

      def front_command
        if (File.exists?(front_local_cache) && File.directory?(front_local_cache))
          puts "[FRONT] updating front local cache to revision #{front_revision}"
          cmd = front_sync_command
        end
        unless (File.exists?(front_local_cache) || File.directory?(front_local_cache))
          puts "[FRONT] creating front local cache with revision #{front_revision}"
          File.delete(front_local_cache) if File.exists?(front_local_cache)
          Dir.mkdir(File.dirname(front_local_cache)) unless File.directory?(File.dirname(front_local_cache))

          cmd = front_checkout_command
        end
        cmd.gsub("\n", '')
      end

      def front_remote_cache
        lambda do
          cache = front_rsync_remote_cache
          cache = deploy_to + '/' + cache if cache && cache !~ /^\//
          cache
        end
      end
    end
  end
end
