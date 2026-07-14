module Requests
  # Public, token-authenticated CSV export of a course's requests. It has no
  # user session, so it lives outside RequestsController and its user/role/
  # membership before_actions, authenticating solely via the course's
  # read-only API token.
  class ExportsController < ApplicationController
    def show
      course = Course.find_by(id: params[:course_id])
      token = params[:readonly_api_token]

      return render plain: 'Invalid or missing API token', status: :unauthorized unless course && ActiveSupport::SecurityUtils.secure_compare(course.readonly_api_token, token.to_s)

      requests = course.requests.includes(:assignment, :user)
      requests = requests.where(status: params[:status]) if params[:status].present?

      send_data Request.to_csv(requests), filename: 'requests.csv', type: 'text/csv'
    end
  end
end
