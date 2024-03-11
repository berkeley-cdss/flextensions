class CreateLmsCredentialsTable < ActiveRecord::Migration[7.1]
  def change
    create_table :lms_credentials_tables do |t|
      t.string 'lms_name'
      t.string 'username'
      t.string 'password'
      t.string 'token'
      t.timestamps
    end
  end
end
