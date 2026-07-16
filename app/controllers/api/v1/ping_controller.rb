module API
  module V1
    class PingController < BaseController
      # Liveness probe: must stay reachable without a session for load balancers.
      skip_before_action :authenticate_api!

      def ping
        render json: 'pong'.to_json
      end
    end
  end
end
