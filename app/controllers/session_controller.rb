class SessionController < ApplicationController
  # The OmniAuth callbacks run before a session exists, so they must be public.
  skip_before_action :authenticated!, only: %i[omniauth_callback omniauth_failure]

  ## Login work flow explained here
  # Currently the login only supports third-party authentication with Canvas.
  # But the structure to support multiple login methods is largely in place.
  # The omniauth_callback function now does nothing more than calling the
  # create function used for Canvas login. It's just a placeholder.
  #
  # ==================IMPORTANT Canvas Login Explaination========================
  # If you try to use request.env['omniauth.auth'] inside this function,
  # it will return nil. This is because I made omniauth request to Canvas manually
  # and post the Canvas code directly to SessionController#create. Hence, Omniauth never
  # runs. If you want to use omniauth for Canvas login instead, replace the Login button
  # with something like erb<br><%= link_to 'Login with Canvas', '/auth/canvas' %>.
  #
  # =======================How to add another login method========================
  # If you want to add another login method, follow the steps below:
  # 1. Add the new provider to the omniauth.rb file.
  # 2. To avoid change too much existing code, I would suggest to add
  #    more login buttons to the login page (like "logins with Google") or
  #    smth like that. Each button should support one login method. The existing
  #    login button should be used for Canvas login.
  # 3. For each new login button, make a POST request to auth/:provider/.
  #    See BJC-Teacher-Tracker/app/views/sessions/new.html.erb for an example.
  # 4. Currently all login logics are handled in create function. It only handles
  #    Canvas login. You can add more login methods to this function and create
  #    user objects in the same way as Canvas login. You can also move part of
  #    the logic from "create" to "omniauth_callback".

  def logout
    reset_session
    redirect_to root_path
  end

  def omniauth_callback
    if params[:error].present?
      Rails.logger.error("OmniAuth callback error: #{params[:error_description] || params[:error]}")
      redirect_to root_path, alert: 'Authentication failed. Please try again.'
      return
    end

    auth = request.env['omniauth.auth']
    unless auth
      redirect_to root_path, alert: 'Authentication failed. No credentials received.'
      return
    end

    user_data = {
      'id' => auth.uid,
      'name' => auth.info.name,
      'primary_email' => auth.info.email,
      'email' => auth.info.email
    }
    creds = auth.credentials # an OmniAuth::AuthHash

    # dev provider doesnt have real credentials so its stubbed
    expires_at = creds.expires_at || 30.days.from_now.to_i

    access_token = OAuth2::AccessToken.new(
      OAuth2::Client.new('', ''), # client never used – stub
      creds.token,
      refresh_token: creds.refresh_token,
      expires_at: expires_at
    )

    developer = auth.provider == 'developer'
    user =
      if developer
        developer_lookup_or_create(user_data, access_token)
      else
        canvas_lookup_or_create(user_data, access_token)
      end

    # Either path returns nil when it refuses the login (e.g. canvas_lookup
    # declining to re-key an existing account to a new canvas_uid).
    if user.nil?
      redirect_to root_path,
                  alert: 'We could not link your account. Please contact an administrator.'
      return
    end

    # Auto-enroll developer login users in test courses
    ensure_developer_test_enrollments(user) if developer

    redirect_to courses_path, notice: "Logged in! Welcome, #{user_data['name']}!"
  rescue StandardError => e
    Rails.logger.error("OmniAuth callback error: #{e.message}")
    Rails.error.report(e, handled: true, context: { component: 'omniauth_callback' })
    redirect_to root_path, alert: 'Authentication failed. Invalid credentials.'
  end

  def omniauth_failure
    redirect_to root_path, alert: 'Authentication failed. Please try again.'
  end

  def destroy
    redirect_to :logout, notice: 'Logged out!'
  end

  private

  def ensure_developer_test_enrollments(user)
    # Find the test course
    test_course = Course.find_by(course_code: 'DEV101')

    # Ensure enrollment in the test course (as student so they can request extensions)
    if test_course
      Enrollment.find_or_create_by!(user_id: user.id, course_id: test_course.id) do |enrollment|
        enrollment.role = 'student'
      end
    end
  end

  def developer_login_allowed?
    Rails.env.local?
  end

  # Canonical production login path. Canvas owns identity, so users are keyed by
  # canvas_uid: we refresh the email on a canvas_uid match and create a new
  # account when the canvas_uid is unknown. We return nil (rather than re-keying)
  # when a different canvas_uid presents an email that already belongs to an
  # account, leaving the existing account untouched.
  def canvas_lookup_or_create(user_data, auth_token)
    user = User.find_by(canvas_uid: user_data['id'])

    if user
      user.email = user_data['email']
    elsif User.exists?(email: user_data['primary_email'])
      Rails.logger.warn(
        "Refusing to link canvas_uid=#{user_data['id']} to existing account " \
        "with email=#{user_data['primary_email']}"
      )
      return nil
    else
      user = User.new(canvas_uid: user_data['id'])
      user.assign_attributes(
        email: user_data['email'],
        name: user_data['name']
      )
    end

    persist_login!(user, auth_token)
  end

  # Developer / test masquerade path. INTENTIONALLY matches an existing user by
  # email so a developer can log in *as* them without Canvas. Gated to dev/test
  # only; returns nil otherwise. Do not use this matching for the Canvas path.
  def developer_lookup_or_create(user_data, auth_token)
    return nil unless developer_login_allowed?

    if User.exists?(email: user_data['primary_email'])
      user = User.find_by(email: user_data['primary_email'])
      user.canvas_uid = user_data['id']
    elsif User.exists?(canvas_uid: user_data['id'])
      user = User.find_by(canvas_uid: user_data['id'])
      user.email = user_data['email']
    else
      user = User.find_or_initialize_by(canvas_uid: user_data['id'])
      user.assign_attributes(
        email: user_data['email'],
        name: user_data['name']
      )
    end

    persist_login!(user, auth_token)
  end

  # Shared finalization for both login paths: persist the user, refresh their
  # LMS credentials, and establish the session.
  def persist_login!(user, auth_token)
    user.save!
    update_user_credential(user, auth_token)

    # Guard against session fixation: issue a fresh session before storing the
    # authenticated user's identity, so any session id an attacker may have
    # fixated is discarded at the moment of login.
    reset_session

    # Store user ID in session for authentication
    session[:username] = user.name
    session[:user_id] = user.canvas_uid

    user
  end

  # TODO: Move this to a Canvas API libarary or user service
  # TODO: Find credentals for the right LMS, not just the first one.
  def update_user_credential(user, token)
    if user.lms_credentials.any?
      user.lms_credentials.first.update(
        token: token.token,
        refresh_token: token.refresh_token,
        expire_time: Time.zone.at(token.expires_at)
      )
    else
      user.lms_credentials.create!(
        lms_id: Lms.CANVAS_LMS.id,
        token: token.token,
        refresh_token: token.refresh_token,
        expire_time: Time.zone.at(token.expires_at)
      )
    end
  end
end
