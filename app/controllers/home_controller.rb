class HomeController < ApplicationController
  # The landing page is the pre-login entry point.
  skip_before_action :authenticated!, only: :index

  def index
    return unless current_user.logged_in?

    redirect_to courses_path
  end
end
