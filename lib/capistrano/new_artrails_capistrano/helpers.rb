# frozen_string_literal: true

module Capistrano
  module NewArtrailsCapistrano
    module Helpers
      def new_artrails_capistrano_sudo_as
        "#{fetch(:new_artrails_capistrano_sudo_as)}" || 'deploy'
      end

      def file_exists?(path)
        test "[ -e #{path} ]"
      end

      def dir_exists?(path)
        test "[ -d #{path} ]"
      end

      def copy_command
        "rsync -a --no-p --no-g --delete"
      end

      def rsync_remote_cache
        fetch(:remote_cache) || "shared/cached-copy-#{fetch(:local_user) || 'deploy'}"
      end

      def new_artrails_capistrano_detect_manifest_path
         %w(
           .sprockets-manifest*
           manifest*.*
         ).each do |pattern|
           candidate = release_path.join('public', fetch(:assets_prefix), pattern)
           return capture(:ls, candidate).strip.gsub(/(\r|\n)/,' ') if test(:ls, candidate)
         end
         msg = 'Rails assets manifest file not found.'
         warn msg
         # Rails 5 only
         # fail Capistrano::FileNotFound, msg
       end

      def new_artrails_capistrano_run_with_rvm_in_release_path(cmd, options={}, &block)
        joined_cmd =<<-CMD
          sudo -iu #{fetch(:new_artrails_capistrano_sudo_as)} sh -c "
          source\\\\ '/usr/local/rvm/scripts/rvm' &&
          cd #{fetch(:release_path)} &&
          RAILS_ENV=#{fetch(:rails_env)} #{cmd}
          "
        CMD
        new_artrails_capistrano_run(joined_cmd.gsub(/\r?\n/, '').gsub(/\s+/, ' '), options) do
          block.call
        end
      end

      def new_artrails_capistrano_run(cmd, options={}, &block)
        if cmd.include?('db:migrate')
          c = cmd.split(';')

          c.each_index do |index|
            if c[index].strip[0..4].include?('rake ') && c[index].include?('db:migrate')
              c[index] = " sudo -i -u #{new_artrails_capistrano_sudo_as} " + c[index]
            end
          end

          cmd = c.join(';')
        end
        if cmd.include?('find')
          cmd = "sudo -u #{new_artrails_capistrano_sudo_as} " + cmd
        end

        if cmd.strip[0..3] != 'pwd '  &&
          !cmd.include?( 'sudo' )  &&
          !cmd.include?( 'chmod +r+w+x' )  &&
          !cmd.include?( 'chmod g+w' )  &&
          !cmd.include?( 'chgrp -R mongrel' ) &&
          !cmd.include?( 'find' )
          if !cmd.include?( ' && (' )  &&  !cmd.include?( 'sh -c' )
            cmd = cmd.gsub( /\s&&\s/, " && sudo -i -u #{new_artrails_capistrano_sudo_as} " )
          end
          if !cmd.include?(' | (') && !cmd.include?('sh -c')
            cmd = cmd.gsub(/\s\|\s/, " | sudo -i -u #{new_artrails_capistrano_sudo_as} ")
          end

          cmd = "sudo -i -u #{new_artrails_capistrano_sudo_as} " + cmd
        end

        execute(cmd, options, &block)
      end
    end
  end
end
