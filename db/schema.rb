# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_03_13_230106) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "assignments", force: :cascade do |t|
    t.string "assignment_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "courses", force: :cascade do |t|
    t.string "course_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "coursetoplatforms", force: :cascade do |t|
    t.bigint "platform_id"
    t.bigint "course_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_coursetoplatforms_on_course_id"
    t.index ["platform_id"], name: "index_coursetoplatforms_on_platform_id"
  end

  create_table "extensions", force: :cascade do |t|
    t.string "student_email"
    t.datetime "initial_due_date"
    t.datetime "new_due_date"
    t.bigint "last_processed_by_user_id"
    t.bigint "assignment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id"], name: "index_extensions_on_assignment_id"
  end

  create_table "lmss", force: :cascade do |t|
    t.string "lms_name"
    t.boolean "use_auth_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "platforms", force: :cascade do |t|
    t.string "platform_name"
    t.boolean "use_auth_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "usertocourses", force: :cascade do |t|
    t.bigint "course_id"
    t.bigint "user_id"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_usertocourses_on_course_id"
    t.index ["user_id"], name: "index_usertocourses_on_user_id"
  end

  add_foreign_key "coursetoplatforms", "courses"
  add_foreign_key "coursetoplatforms", "platforms"
  add_foreign_key "extensions", "assignments"
  add_foreign_key "usertocourses", "courses"
  add_foreign_key "usertocourses", "users"
end
