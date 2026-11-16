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

ActiveRecord::Schema[8.1].define(version: 2026_11_16_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "allergies", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.string "ingredient", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["patient_id", "ingredient"], name: "index_allergies_on_patient_id_and_ingredient", unique: true
    t.index ["patient_id"], name: "index_allergies_on_patient_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.string "action", null: false
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.string "summary", null: false
    t.jsonb "change_set", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
  end

  create_table "doses", force: :cascade do |t|
    t.bigint "prescription_id", null: false
    t.bigint "patient_id", null: false
    t.datetime "scheduled_at", null: false
    t.date "local_date", null: false
    t.string "local_time", null: false
    t.boolean "dst_adjusted", default: false, null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "recorded_at"
    t.bigint "recorded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["patient_id", "scheduled_at"], name: "index_doses_on_patient_id_and_scheduled_at"
    t.index ["patient_id"], name: "index_doses_on_patient_id"
    t.index ["prescription_id", "scheduled_at"], name: "index_doses_on_prescription_id_and_scheduled_at", unique: true
    t.index ["prescription_id"], name: "index_doses_on_prescription_id"
    t.index ["recorded_by_id"], name: "index_doses_on_recorded_by_id"
    t.check_constraint "status::text = ANY (ARRAY['scheduled'::character varying, 'taken'::character varying, 'missed'::character varying]::text[])", name: "doses_status_check"
  end

  create_table "interactions", force: :cascade do |t|
    t.bigint "medication_a_id", null: false
    t.bigint "medication_b_id", null: false
    t.string "severity", null: false
    t.string "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["medication_a_id", "medication_b_id"], name: "index_interactions_on_pair", unique: true
    t.index ["medication_a_id"], name: "index_interactions_on_medication_a_id"
    t.index ["medication_b_id"], name: "index_interactions_on_medication_b_id"
    t.check_constraint "medication_a_id < medication_b_id", name: "interactions_ordered_pair_check"
    t.check_constraint "severity::text = ANY (ARRAY['major'::character varying, 'moderate'::character varying, 'minor'::character varying]::text[])", name: "interactions_severity_check"
  end

  create_table "medications", force: :cascade do |t|
    t.string "name", null: false
    t.string "generic_name", null: false
    t.string "ingredient", null: false
    t.string "strength", null: false
    t.string "form", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient"], name: "index_medications_on_ingredient"
    t.index ["name", "strength"], name: "index_medications_on_name_and_strength", unique: true
  end

  create_table "prescriptions", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.bigint "doctor_id", null: false
    t.bigint "medication_id", null: false
    t.decimal "dose_quantity", precision: 8, scale: 2, null: false
    t.string "dose_unit", null: false
    t.string "frequency", null: false
    t.integer "interval_hours"
    t.jsonb "times_of_day", default: [], null: false
    t.integer "duration_days", null: false
    t.date "start_date", null: false
    t.string "timezone", null: false
    t.string "status", default: "active", null: false
    t.boolean "warning_acknowledged", default: false, null: false
    t.jsonb "warnings", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["doctor_id"], name: "index_prescriptions_on_doctor_id"
    t.index ["medication_id"], name: "index_prescriptions_on_medication_id"
    t.index ["patient_id", "status"], name: "index_prescriptions_on_patient_id_and_status"
    t.index ["patient_id"], name: "index_prescriptions_on_patient_id"
    t.check_constraint "frequency::text = ANY (ARRAY['once_daily'::character varying, 'twice_daily'::character varying, 'three_times_daily'::character varying, 'every_n_hours'::character varying]::text[])", name: "prescriptions_frequency_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'cancelled'::character varying]::text[])", name: "prescriptions_status_check"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.string "role", null: false
    t.string "timezone", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "role::text = ANY (ARRAY['doctor'::character varying, 'patient'::character varying, 'pharmacist'::character varying]::text[])", name: "users_role_check"
  end

  add_foreign_key "allergies", "users", column: "patient_id"
  add_foreign_key "audit_logs", "users", column: "actor_id"
  add_foreign_key "doses", "prescriptions"
  add_foreign_key "doses", "users", column: "patient_id"
  add_foreign_key "doses", "users", column: "recorded_by_id"
  add_foreign_key "interactions", "medications", column: "medication_a_id"
  add_foreign_key "interactions", "medications", column: "medication_b_id"
  add_foreign_key "prescriptions", "medications"
  add_foreign_key "prescriptions", "users", column: "doctor_id"
  add_foreign_key "prescriptions", "users", column: "patient_id"
end
