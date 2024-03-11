class CreateLmssTable < ActiveRecord::Migration[7.1]
  def change
    create_table :lmss_tables do |t|
      t.string 'name'
      t.boolean 'use_auth_token'
      t.timestamps
    end
  end
end
