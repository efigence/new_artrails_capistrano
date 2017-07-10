# frozen_string_literal: true

module Capistrano
  module NewArtrailsCapistrano
    module Helpers
      def new_artrails_capistrano_process_owner_user
        "#{fetch(:process_owner_user)}" || 'deploy'
      end

      def file_exists?(path)
        test "[ -e #{path} ]"
      end

      def deploy_user
        capture :id, '-un'
      end
    end
  end
end
