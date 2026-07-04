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

ActiveRecord::Schema[8.1].define(version: 2026_07_04_000001) do
  create_schema "hypershield"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "form_display_status", ["required", "optional", "hidden"]
  create_enum "request_status", ["pending", "approved", "denied"]

  create_table "assignments", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "course_to_lms_id", null: false
    t.datetime "created_at", null: false
    t.datetime "due_date"
    t.boolean "enabled", default: false
    t.string "external_assignment_id"
    t.datetime "late_due_date"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_assignments_on_course_id"
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
    t.boolean "enable_min_hours_before_deadline", default: true, null: false
    t.boolean "enable_slack_webhook_url"
    t.boolean "extend_late_due_date", default: true, null: false
    t.string "gradescope_course_url"
    t.integer "max_auto_approve", default: 0
    t.integer "min_hours_before_deadline", default: 0, null: false
    t.string "pending_notification_email"
    t.string "pending_notification_frequency"
    t.string "reply_email"
    t.string "slack_webhook_url"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_course_settings_on_course_id", unique: true
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
    t.boolean "demo_course", default: false, null: false
    t.string "readonly_api_token"
    t.string "semester"
    t.datetime "updated_at", null: false
    t.index ["canvas_id"], name: "index_courses_on_canvas_id", unique: true
    t.index ["readonly_api_token"], name: "index_courses_on_readonly_api_token", unique: true
  end

  create_table "enrollments", force: :cascade do |t|
    t.boolean "allow_extended_requests", default: false, null: false
    t.bigint "course_id"
    t.datetime "created_at", null: false
    t.boolean "removed", default: false, null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["course_id"], name: "index_enrollments_on_course_id"
    t.index ["user_id"], name: "index_enrollments_on_user_id"
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

  create_table "faultline_error_contexts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "error_occurrence_id", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["error_occurrence_id", "key"], name: "index_faultline_error_contexts_on_error_occurrence_id_and_key"
    t.index ["error_occurrence_id"], name: "index_faultline_error_contexts_on_error_occurrence_id"
  end

  create_table "faultline_error_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "exception_class", null: false
    t.string "file_path"
    t.string "fingerprint", null: false
    t.datetime "first_seen_at"
    t.datetime "last_notified_at"
    t.datetime "last_seen_at"
    t.integer "line_number"
    t.string "method_name"
    t.integer "occurrences_count", default: 0
    t.datetime "resolved_at"
    t.text "sanitized_message", null: false
    t.virtual "searchable", type: :tsvector, as: "to_tsvector('simple'::regconfig, (((((COALESCE(exception_class, ''::character varying))::text || ' '::text) || COALESCE(sanitized_message, ''::text)) || ' '::text) || (COALESCE(file_path, ''::character varying))::text))", stored: true
    t.string "status", default: "unresolved"
    t.datetime "updated_at", null: false
    t.index ["exception_class"], name: "index_faultline_error_groups_on_exception_class"
    t.index ["fingerprint"], name: "index_faultline_error_groups_on_fingerprint", unique: true
    t.index ["last_seen_at"], name: "index_faultline_error_groups_on_last_seen_at"
    t.index ["searchable"], name: "index_faultline_error_groups_on_searchable", using: :gin
    t.index ["status"], name: "index_faultline_error_groups_on_status"
  end

  create_table "faultline_error_occurrences", force: :cascade do |t|
    t.text "backtrace"
    t.datetime "created_at", null: false
    t.string "environment"
    t.bigint "error_group_id", null: false
    t.string "exception_class", null: false
    t.string "hostname"
    t.string "ip_address"
    t.json "local_variables"
    t.text "message", null: false
    t.string "process_id"
    t.text "request_headers"
    t.string "request_method"
    t.text "request_params"
    t.string "request_url"
    t.string "session_id"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id"
    t.string "user_type"
    t.index ["created_at"], name: "index_faultline_error_occurrences_on_created_at"
    t.index ["error_group_id", "created_at"], name: "idx_on_error_group_id_created_at_98b32c40ac"
    t.index ["error_group_id"], name: "index_faultline_error_occurrences_on_error_group_id"
    t.index ["user_type", "user_id"], name: "index_faultline_error_occurrences_on_user_type_and_user_id"
  end

  create_table "faultline_request_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "interval_ms"
    t.string "mode", default: "cpu"
    t.text "profile_data", null: false
    t.bigint "request_trace_id", null: false
    t.integer "samples", default: 0
    t.index ["request_trace_id"], name: "index_faultline_request_profiles_on_request_trace_id"
  end

  create_table "faultline_request_traces", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "db_query_count", default: 0
    t.float "db_runtime_ms"
    t.float "duration_ms"
    t.string "endpoint", null: false
    t.boolean "has_profile", default: false
    t.string "http_method", null: false
    t.string "path"
    t.json "spans"
    t.integer "status"
    t.float "view_runtime_ms"
    t.index ["created_at"], name: "index_faultline_request_traces_on_created_at"
    t.index ["endpoint", "created_at"], name: "index_faultline_request_traces_on_endpoint_and_created_at"
    t.index ["endpoint"], name: "index_faultline_request_traces_on_endpoint"
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
    t.bigint "lms_id"
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
  add_foreign_key "assignments", "courses"
  add_foreign_key "course_settings", "courses"
  add_foreign_key "course_to_lmss", "courses"
  add_foreign_key "course_to_lmss", "lmss"
  add_foreign_key "enrollments", "courses"
  add_foreign_key "enrollments", "users"
  add_foreign_key "extensions", "assignments"
  add_foreign_key "extensions", "users", column: "last_processed_by_id"
  add_foreign_key "faultline_error_contexts", "faultline_error_occurrences", column: "error_occurrence_id"
  add_foreign_key "faultline_error_occurrences", "faultline_error_groups", column: "error_group_id"
  add_foreign_key "faultline_request_profiles", "faultline_request_traces", column: "request_trace_id", on_delete: :cascade
  add_foreign_key "form_settings", "courses"
  add_foreign_key "lms_credentials", "lmss"
  add_foreign_key "lms_credentials", "users"
  add_foreign_key "requests", "assignments"
  add_foreign_key "requests", "courses"
  add_foreign_key "requests", "users"
  add_foreign_key "requests", "users", column: "last_processed_by_user_id"
end
