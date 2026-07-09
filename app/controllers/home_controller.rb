class HomeController < ApplicationController
  # The landing page is the pre-login entry point.
  skip_before_action :authenticated!, only: :index

  def index
    return if session[:user_id].blank?

    redirect_to courses_path
  end
end
