require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  describe 'GET #index' do
    context 'when no user is logged in' do
      it 'renders the index page' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end

    context 'when user is logged in' do
      before { session[:user_id] = create(:user).canvas_uid }

      it 'redirects to courses_path' do
        get :index
        expect(response).to redirect_to(courses_path)
      end
    end

    context 'when some account has a null canvas_uid' do
      # Regression. `User.find_by(canvas_uid: nil)` is not "no user" -- it
      # compiles to `WHERE canvas_uid IS NULL LIMIT 1` and returns that account,
      # so anonymous visitors resolved to a real user and got redirected to
      # /courses. The load balancer polls `/` and requires 200, which is why
      # every production deployment failed its health check.
      before { User.create!(email: 'orphan@example.com', canvas_uid: nil) }

      it 'still renders the index page for an anonymous visitor' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end

    context 'when the session points at a user that no longer exists' do
      before { session[:user_id] = 'nonexistent-uid' }

      # current_user is a NullUser here, so the visitor is treated as logged
      # out and stays on the landing page rather than being sent to /courses
      # only to be bounced straight back by `authenticated!`.
      it 'renders the index page' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end
  end
end
