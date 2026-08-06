module API
  module V1
    class PingController < BaseController
      # Liveness probe: must stay reachable without a session for load balancers,
      # and in every environment (not just test), so it opts out of both gates.
      skip_before_action :require_api_available!
      skip_before_action :authenticate_api!

      def ping
        render json: 'pong'.to_json
      end
    end
  end
end
