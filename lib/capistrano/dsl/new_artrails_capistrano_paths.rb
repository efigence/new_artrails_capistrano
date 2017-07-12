# frozen_string_literal: true

module Capistrano
  module DSL
    module NewArtrailsCapistranoPaths
      def new_artrails_capistrano_remote_cache
        "shared/cached-copy-#{fetch(:local_user) || 'deploy'}"
      end
      def new_artrails_capistrano_front_remote_cache
        "shared/front-cached-copy-#{fetch(:local_user) || 'deploy'}"
      end
      def new_artrails_capistrano_log_dir_name
        File.basename(fetch(:deploy_to) || fetch(:application))
      end
    end
  end
end
