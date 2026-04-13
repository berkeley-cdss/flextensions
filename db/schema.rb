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

ActiveRecord::Schema[8.1].define(version: 2026_03_06_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "form_display_status", ["required", "optional", "hidden"]
  create_enum "request_status", ["pending", "approved", "denied"]

  create_table "assignments", force: :cascade do |t|
    t.bigint "course_to_lms_id", null: false
    t.datetime "created_at", null: false
    t.datetime "due_date"
    t.boolean "enabled", default: false
    t.string "external_assignment_id"
    t.datetime "late_due_date"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "blazer_audits", force: :cascade do |t|
    t.datetime "created_at"
    t.string "data_source"
    t.bigint "query_id"
    t.text "statement"
    t.bigint "user_id"
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", force: :cascade do |t|
    t.string "check_type"
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.text "emails"
    t.datetime "last_run_at"
    t.text "message"
    t.bigint "query_id"
    t.string "schedule"
    t.text "slack_channels"
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dashboard_id"
    t.integer "position"
    t.bigint "query_id"
    t.datetime "updated_at", null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "data_source"
    t.text "description"
    t.string "name"
    t.text "statement"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "course_settings", force: :cascade do |t|
    t.integer "auto_approve_days", default: 0
    t.integer "auto_approve_extended_request_days", default: 0
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.string "email_subject", default: "Extension Request Status: {{status}} - {{course_code}}"
    t.text "email_template", default: "Dear {{student_name}},\n\nYour extension request for {{assignment_name}} in {{course_name}} ({{course_code}}) has been {{status}}.\n\nExtension Details:\n- Original Due Date: {{original_due_date}}\n- New Due Date: {{new_due_date}}\n- Extension Days: {{extension_days}}\n\nIf you have any questions, please contact the course staff.\n\nBest regards,\n{{course_name}} Staff"
    t.boolean "enable_emails", default: false
    t.boolean "enable_extensions", default: false
    t.boolean "enable_gradescope", default: false
    t.boolean "enable_slack_webhook_url"
    t.boolean "extend_late_due_date", default: true, null: false
    t.string "gradescope_course_url"
    t.integer "max_auto_approve", default: 0
    t.string "reply_email"
    t.string "slack_webhook_url"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_course_settings_on_course_id"
  end

  create_table "course_to_lmss", force: :cascade do |t|
    t.bigint "course_id"
    t.datetime "created_at", null: false
    t.string "external_course_id"
    t.bigint "lms_id"
    t.jsonb "recent_assignment_sync", default: {}
    t.jsonb "recent_roster_sync", default: {}
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_course_to_lmss_on_course_id"
    t.index ["lms_id"], name: "index_course_to_lmss_on_lms_id"
  end

  create_table "courses", force: :cascade do |t|
    t.string "canvas_id"
    t.string "course_code"
    t.string "course_name"
    t.datetime "created_at", null: false
    t.string "readonly_api_token"
    t.string "semester"
    t.datetime "updated_at", null: false
    t.index ["canvas_id"], name: "index_courses_on_canvas_id", unique: true
    t.index ["readonly_api_token"], name: "index_courses_on_readonly_api_token", unique: true
  end

  create_table "extensions", force: :cascade do |t|
    t.bigint "assignment_id"
    t.datetime "created_at", null: false
    t.string "external_extension_id"
    t.datetime "initial_due_date"
    t.bigint "last_processed_by_id"
    t.datetime "new_due_date"
    t.string "student_email"
    t.datetime "updated_at", null: false
    t.index ["assignment_id"], name: "index_extensions_on_assignment_id"
    t.index ["last_processed_by_id"], name: "index_extensions_on_last_processed_by_id"
  end

  create_table "form_settings", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.string "custom_q1"
    t.text "custom_q1_desc"
    t.enum "custom_q1_disp", enum_type: "form_display_status"
    t.string "custom_q2"
    t.text "custom_q2_desc"
    t.enum "custom_q2_disp", enum_type: "form_display_status"
    t.text "documentation_desc"
    t.enum "documentation_disp", enum_type: "form_display_status"
    t.text "reason_desc"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_form_settings_on_course_id"
  end

  create_table "lms_credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expire_time"
    t.string "external_user_id"
    t.string "lms_name"
    t.string "password"
    t.string "refresh_token"
    t.string "token"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "username"
    t.index ["user_id"], name: "index_lms_credentials_on_user_id"
  end

  create_table "lmss", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "lms_base_url"
    t.string "lms_name"
    t.datetime "updated_at", null: false
    t.boolean "use_auth_token"
  end

  create_table "requests", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.boolean "auto_approved", default: false, null: false
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.text "custom_q1"
    t.text "custom_q2"
    t.text "documentation"
    t.string "external_extension_id"
    t.bigint "last_processed_by_user_id"
    t.text "reason"
    t.datetime "requested_due_date"
    t.enum "status", default: "pending", null: false, enum_type: "request_status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["assignment_id"], name: "index_requests_on_assignment_id"
    t.index ["auto_approved"], name: "index_requests_on_auto_approved"
    t.index ["course_id"], name: "index_requests_on_course_id"
    t.index ["last_processed_by_user_id"], name: "index_requests_on_last_processed_by_user_id"
    t.index ["user_id"], name: "index_requests_on_user_id"
  end

  create_table "user_to_courses", force: :cascade do |t|
    t.boolean "allow_extended_requests", default: false, null: false
    t.bigint "course_id"
    t.datetime "created_at", null: false
    t.boolean "removed", default: false, null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["course_id"], name: "index_user_to_courses_on_course_id"
    t.index ["user_id"], name: "index_user_to_courses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.string "canvas_uid"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "student_id"
    t.datetime "updated_at", null: false
    t.index ["canvas_uid"], name: "index_users_on_canvas_uid", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "assignments", "course_to_lmss"
  add_foreign_key "course_settings", "courses"
  add_foreign_key "course_to_lmss", "courses"
  add_foreign_key "course_to_lmss", "lmss"
  add_foreign_key "extensions", "assignments"
  add_foreign_key "extensions", "users", column: "last_processed_by_id"
  add_foreign_key "form_settings", "courses"
  add_foreign_key "lms_credentials", "users"
  add_foreign_key "requests", "assignments"
  add_foreign_key "requests", "courses"
  add_foreign_key "requests", "users"
  add_foreign_key "requests", "users", column: "last_processed_by_user_id"
  add_foreign_key "user_to_courses", "courses"
  add_foreign_key "user_to_courses", "users"
end
