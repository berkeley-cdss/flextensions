class AddCompositeIndexesToRequests < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Requests are always filtered by course plus status (the pending count on
  # every course page, the staff list, exports, approved-late-day totals) or by
  # user plus course (the student list, the auto-approval checks). The old
  # single-column indexes on course_id and user_id are the leading columns of
  # the new composites, so they are redundant, and the index on the boolean
  # auto_approved is never used on its own.
  def change
    add_index :requests, [ :course_id, :status ], algorithm: :concurrently
    add_index :requests, [ :user_id, :course_id ], algorithm: :concurrently

    remove_index :requests, :course_id, algorithm: :concurrently
    remove_index :requests, :user_id, algorithm: :concurrently
    remove_index :requests, :auto_approved, algorithm: :concurrently
  end
end
