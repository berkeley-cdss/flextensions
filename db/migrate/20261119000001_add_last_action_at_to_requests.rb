# last_action_at is when a request was last approved or denied. Until now
# updated_at stood in for that, but updated_at also moves on unrelated writes.
class AddLastActionAtToRequests < ActiveRecord::Migration[8.1]
  class MigrationRequest < ActiveRecord::Base
    self.table_name = 'requests'
  end

  def up
    add_column :requests, :last_action_at, :datetime

    # updated_at is the best record we have of when existing requests were decided.
    MigrationRequest.where.not(status: 'pending').update_all('last_action_at = updated_at')
  end

  def down
    remove_column :requests, :last_action_at
  end
end
