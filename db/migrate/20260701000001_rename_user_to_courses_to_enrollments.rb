class RenameUserToCoursesToEnrollments < ActiveRecord::Migration[7.2]
  # This migration shipped twice under two different version numbers:
  # 20260701000001 (ca6fa79b) and 20260704000001 (470cc567). f00b46a2 deleted
  # the 0704 file, but any database that had already applied it still records
  # only 20260704000001 -- so it sees 20260701000001 as pending and tries to
  # rename a table that is already named `enrollments`. That raises
  # PG::UndefinedTable, which aborts the entire `db:migrate` run and, under
  # Elastic Beanstalk's immutable deploys, fails the deployment *after* earlier
  # migrations have already committed. Guard on the end state instead of
  # assuming which of the two versions a given database recorded.
  def up
    return if connection.table_exists?(:enrollments)

    # The table is small, so renaming it is safe.
    # rename_table also renames the primary key sequence and the
    # index_user_to_courses_on_* indexes to match the new table name.
    safety_assured do
      rename_table :user_to_courses, :enrollments
    end
  end

  def down
    return if connection.table_exists?(:user_to_courses)

    safety_assured do
      rename_table :enrollments, :user_to_courses
    end
  end
end
