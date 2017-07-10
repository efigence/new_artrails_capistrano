# frozen_string_literal: true

module Capistrano
  module DSL
    module NewArtrailsCapistranoPaths
      def new_artrails_capistrano_remote_cache
        "cached-copy-#{fetch(:local_user)}"
      end
      def new_artrails_capistrano_front_remote_cache
        "front-cached-copy-#{fetch(:local_user)}"
      end
    end
  end
end
