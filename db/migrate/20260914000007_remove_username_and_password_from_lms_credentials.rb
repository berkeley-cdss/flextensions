class RemoveUsernameAndPasswordFromLmsCredentials < ActiveRecord::Migration[8.1]
  # Never read or written by the app: every LMS is accessed with OAuth tokens.
  # password was also outside the encrypted attributes, so it must not linger.
  def change
    safety_assured do
      remove_column :lms_credentials, :username, :string
      remove_column :lms_credentials, :password, :string
    end
  end
end
