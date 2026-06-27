class SessionController < ApplicationController
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
    refresh_token = creds.refresh_token || 'none'

    access_token = OAuth2::AccessToken.new(
      OAuth2::Client.new('', ''), # client never used – stub
      creds.token,
      refresh_token: refresh_token,
      expires_at: expires_at
    )

    # Choose the account-resolution path based on the provider.
    #
    # The :developer provider is a deliberate masquerade hole that lets a
    # developer log in *as* an existing user without going through Canvas. It
    # must never be reachable in production, so we gate it twice: the provider
    # is only registered in dev/test (config/initializers/omniauth.rb) AND we
    # re-check developer_login_allowed? here as defense in depth.
    developer = auth.provider == 'developer'
    if developer && !developer_login_allowed?
      Rails.logger.error('Developer login attempted in a non-permitted environment')
      redirect_to root_path, alert: 'Authentication failed. Please try again.'
      return
    end

    user =
      if developer
        developer_lookup_or_create(user_data, access_token)
      else
        canvas_lookup_or_create(user_data, access_token)
      end

    # canvas_lookup_or_create returns nil when it refuses to silently re-key an
    # existing account to a new canvas_uid (potential account takeover).
    if user.nil?
      redirect_to root_path,
                  alert: 'We could not link your Canvas account to an existing ' \
                         'account with the same email. Please contact an administrator.'
      return
    end

    # Auto-enroll developer login users in test courses
    ensure_developer_test_enrollments(user) if developer

    redirect_to courses_path, notice: "Logged in! Welcome, #{user_data['name']}!"
  rescue StandardError => e
    Rails.logger.error("OmniAuth callback error: #{e.message}")
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
      UserToCourse.find_or_create_by!(user_id: user.id, course_id: test_course.id) do |utc|
        utc.role = 'student'
      end
    end
  end

  # Whether the developer (masquerade) login path may be used.
  #
  # This mirrors the env guard that registers the :developer OmniAuth provider
  # in config/initializers/omniauth.rb -- both must be true for developer login
  # to be reachable. Keeping the check here (and not only in the initializer)
  # ensures the impersonation path can never run in production even if a
  # :developer callback somehow reaches the controller.
  def developer_login_allowed?
    # Rails.env.local? is true only in development and test, matching the env
    # guard around the :developer provider in config/initializers/omniauth.rb.
    Rails.env.local?
  end

  # Canonical production login path.
  #
  # Canvas is the source of truth for identity, so a user is keyed by their
  # canvas_uid:
  #   * If we recognize the canvas_uid, we refresh the email from Canvas.
  #   * If we DON'T recognize the canvas_uid but the incoming email already
  #     belongs to another account, we REFUSE to re-key that account to the new
  #     canvas_uid and return nil. Silently re-keying would let anyone able to
  #     create a Canvas account with a victim's email take over the victim's
  #     account here.
  #   * Otherwise we create a brand new account.
  def canvas_lookup_or_create(user_data, auth_token)
    user = User.find_by(canvas_uid: user_data['id'])

    if user
      user.email = user_data['email']
    elsif User.exists?(email: user_data['primary_email'])
      # A different canvas_uid is presenting an email we already know. Refuse
      # the silent account re-key (potential takeover) and let the caller
      # surface an error to the user.
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

  # Developer / test masquerade path.
  #
  # This INTENTIONALLY preserves the legacy email-first matching so a developer
  # can log in *as* an existing user without going through Canvas. It is a
  # deliberate impersonation hole and is only ever reached when
  # developer_login_allowed? is true (see omniauth_callback and omniauth.rb).
  # Do NOT use this logic for the production Canvas path -- see
  # canvas_lookup_or_create for why email-first matching is unsafe there.
  def developer_lookup_or_create(user_data, auth_token)
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
        lms_name: 'canvas',
        token: token.token,
        refresh_token: token.refresh_token,
        expire_time: Time.zone.at(token.expires_at)
      )
    end
  end
end
