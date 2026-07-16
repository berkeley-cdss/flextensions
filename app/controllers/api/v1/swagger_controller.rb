require 'json'

module API
  module V1
    class SwaggerController < BaseController
      # The API schema is public documentation; no session required.
      skip_before_action :authenticate_api!

      def read
        specFile = File.read("#{Rails.root}app/assets/swagger/swagger.json")
        render json: specFile
      end
    end
  end
end
