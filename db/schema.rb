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

ActiveRecord::Schema[7.0].define(version: 2026_03_08_004602) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "academic_periods", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["school_id"], name: "index_academic_periods_on_school_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activity_grades", force: :cascade do |t|
    t.bigint "evaluation_activity_id", null: false
    t.bigint "student_id", null: false
    t.decimal "score", precision: 4, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["evaluation_activity_id", "student_id"], name: "index_activity_grades_on_activity_and_student", unique: true
    t.index ["evaluation_activity_id"], name: "index_activity_grades_on_evaluation_activity_id"
    t.index ["student_id"], name: "index_activity_grades_on_student_id"
  end

  create_table "activity_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.string "message", null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.jsonb "metadata", default: {}
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_activity_logs_on_action"
    t.index ["created_at"], name: "index_activity_logs_on_created_at"
    t.index ["subject_type", "subject_id"], name: "index_activity_logs_on_subject"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "estado", null: false
    t.string "municipio", null: false
    t.string "parroquia", null: false
    t.string "location", null: false
    t.string "additional"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_addresses_on_user_id", unique: true
  end

  create_table "admins", primary_key: "user_id", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.integer "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["school_id"], name: "index_admins_on_school_id"
  end

  create_table "demo_requests", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "institution", null: false
    t.string "phone"
    t.text "message"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_demo_requests_on_email"
    t.index ["status"], name: "index_demo_requests_on_status"
  end

  create_table "departments", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["school_id", "name"], name: "index_departments_on_school_id_and_name", unique: true
    t.index ["school_id"], name: "index_departments_on_school_id"
  end

  create_table "enrollments", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.bigint "student_id", null: false
    t.date "enrollment_date", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["section_id", "student_id"], name: "index_enrollments_on_section_id_and_student_id", unique: true
    t.index ["section_id"], name: "index_enrollments_on_section_id"
    t.index ["student_id"], name: "index_enrollments_on_student_id"
  end

  create_table "evaluation_activities", force: :cascade do |t|
    t.bigint "subject_id", null: false
    t.bigint "section_id", null: false
    t.bigint "evaluation_moment_id", null: false
    t.string "description", null: false
    t.decimal "weight_percentage", precision: 5, scale: 2, null: false
    t.date "date_scheduled", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["evaluation_moment_id"], name: "index_evaluation_activities_on_evaluation_moment_id"
    t.index ["section_id"], name: "index_evaluation_activities_on_section_id"
    t.index ["subject_id"], name: "index_evaluation_activities_on_subject_id"
  end

  create_table "evaluation_moments", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "weight", precision: 5, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "final_grade_books", force: :cascade do |t|
    t.bigint "enrollment_id", null: false
    t.bigint "subject_id", null: false
    t.decimal "annual_average", precision: 4, scale: 2
    t.decimal "remedial_exam_score", precision: 4, scale: 2
    t.decimal "final_score", precision: 4, scale: 2
    t.text "comments"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_id", "subject_id"], name: "index_final_grade_books_on_enrollment_id_and_subject_id", unique: true
    t.index ["enrollment_id"], name: "index_final_grade_books_on_enrollment_id"
    t.index ["subject_id"], name: "index_final_grade_books_on_subject_id"
  end

  create_table "grade_subjects", force: :cascade do |t|
    t.bigint "grade_id", null: false
    t.bigint "subject_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["grade_id", "subject_id"], name: "index_grade_subjects_on_grade_id_and_subject_id", unique: true
    t.index ["grade_id"], name: "index_grade_subjects_on_grade_id"
    t.index ["subject_id"], name: "index_grade_subjects_on_subject_id"
  end

  create_table "grades", force: :cascade do |t|
    t.string "name", null: false
    t.integer "level", null: false
    t.bigint "leader_teacher_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_grades_on_name", unique: true
  end

  create_table "moment_grades", force: :cascade do |t|
    t.bigint "enrollment_id", null: false
    t.bigint "subject_id", null: false
    t.bigint "evaluation_moment_id", null: false
    t.decimal "final_moment_score", precision: 4, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enrollment_id", "subject_id", "evaluation_moment_id"], name: "index_moment_grades_on_enrollment_subject_moment", unique: true
    t.index ["enrollment_id"], name: "index_moment_grades_on_enrollment_id"
    t.index ["evaluation_moment_id"], name: "index_moment_grades_on_evaluation_moment_id"
    t.index ["subject_id"], name: "index_moment_grades_on_subject_id"
  end

  create_table "schools", force: :cascade do |t|
    t.string "dea_code", null: false
    t.string "name", null: false
    t.string "location", null: false
    t.integer "school_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dea_code"], name: "index_schools_on_dea_code", unique: true
  end

  create_table "sections", force: :cascade do |t|
    t.bigint "grade_id", null: false
    t.bigint "academic_period_id", null: false
    t.integer "capacity", null: false
    t.string "name", null: false
    t.string "classroom"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["academic_period_id"], name: "index_sections_on_academic_period_id"
    t.index ["grade_id", "academic_period_id", "name"], name: "index_sections_on_grade_period_name", unique: true
    t.index ["grade_id"], name: "index_sections_on_grade_id"
  end

  create_table "students", primary_key: "user_id", force: :cascade do |t|
    t.string "school_card", null: false
    t.bigint "school_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["school_card"], name: "index_students_on_school_card", unique: true
    t.index ["school_id"], name: "index_students_on_school_id"
  end

  create_table "subjects", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.bigint "department_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_subjects_on_code", unique: true
    t.index ["department_id"], name: "index_subjects_on_department_id"
  end

  create_table "teacher_sections", force: :cascade do |t|
    t.bigint "teacher_id", null: false
    t.bigint "section_id", null: false
    t.bigint "subject_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["section_id", "subject_id"], name: "index_teacher_sections_on_section_and_subject", unique: true
    t.index ["section_id"], name: "index_teacher_sections_on_section_id"
    t.index ["subject_id"], name: "index_teacher_sections_on_subject_id"
    t.index ["teacher_id"], name: "index_teacher_sections_on_teacher_id"
  end

  create_table "teachers", primary_key: "user_id", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["school_id"], name: "index_teachers_on_school_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "id_card"
    t.string "name"
    t.string "last_name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["id_card"], name: "index_users_on_id_card", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "academic_periods", "schools"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activity_grades", "evaluation_activities"
  add_foreign_key "activity_grades", "students", primary_key: "user_id"
  add_foreign_key "activity_logs", "users"
  add_foreign_key "addresses", "users"
  add_foreign_key "admins", "schools"
  add_foreign_key "admins", "users"
  add_foreign_key "departments", "schools"
  add_foreign_key "enrollments", "sections"
  add_foreign_key "enrollments", "students", primary_key: "user_id"
  add_foreign_key "evaluation_activities", "evaluation_moments"
  add_foreign_key "evaluation_activities", "sections"
  add_foreign_key "evaluation_activities", "subjects"
  add_foreign_key "final_grade_books", "enrollments"
  add_foreign_key "final_grade_books", "subjects"
  add_foreign_key "grade_subjects", "grades"
  add_foreign_key "grade_subjects", "subjects"
  add_foreign_key "grades", "teachers", column: "leader_teacher_id", primary_key: "user_id"
  add_foreign_key "moment_grades", "enrollments"
  add_foreign_key "moment_grades", "evaluation_moments"
  add_foreign_key "moment_grades", "subjects"
  add_foreign_key "sections", "academic_periods"
  add_foreign_key "sections", "grades"
  add_foreign_key "students", "schools"
  add_foreign_key "students", "users"
  add_foreign_key "subjects", "departments"
  add_foreign_key "teacher_sections", "sections"
  add_foreign_key "teacher_sections", "subjects"
  add_foreign_key "teacher_sections", "teachers", primary_key: "user_id"
  add_foreign_key "teachers", "schools"
  add_foreign_key "teachers", "users"
end
