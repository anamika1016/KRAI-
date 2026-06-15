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

ActiveRecord::Schema[8.1].define(version: 2026_06_15_133000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "afls", force: :cascade do |t|
    t.string "aadhar"
    t.string "broker_id"
    t.datetime "created_at", null: false
    t.date "date"
    t.string "dispoce"
    t.decimal "estimate_quantity", precision: 18, scale: 4
    t.decimal "estimate_quantity_admin", precision: 18, scale: 4
    t.string "farmer_name"
    t.string "father_name"
    t.string "fco"
    t.string "fco_id"
    t.string "fpo_id"
    t.string "fpo_name"
    t.string "fy"
    t.string "ginning_id"
    t.string "ics_id"
    t.string "ics_name"
    t.string "import_key"
    t.string "ip"
    t.string "khasara_no"
    t.decimal "lattitude", precision: 20, scale: 8
    t.decimal "longitude", precision: 20, scale: 8
    t.string "mobile_no"
    t.date "purchase_date"
    t.string "purchase_product"
    t.string "purchase_product_type"
    t.decimal "purchase_quantity", precision: 18, scale: 4
    t.decimal "purchase_quantity_amount", precision: 18, scale: 4
    t.string "qr_aadhar"
    t.string "qr_mobile"
    t.text "qrcode"
    t.datetime "qrcode_date"
    t.string "reg_type"
    t.string "slip_no"
    t.string "status"
    t.decimal "total_farm_area", precision: 18, scale: 4
    t.string "tracenet_no"
    t.datetime "updated_at", null: false
    t.string "village_id"
    t.string "village_name"
    t.index ["created_at"], name: "index_afls_on_created_at"
    t.index ["farmer_name"], name: "index_afls_on_farmer_name"
    t.index ["fco_id", "ics_id", "village_id"], name: "index_afls_on_mapping_lookup"
    t.index ["mobile_no"], name: "index_afls_on_mobile_no"
    t.index ["slip_no"], name: "index_afls_on_slip_no"
    t.index ["tracenet_no"], name: "index_afls_on_tracenet_no"
  end

  create_table "module_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "data", null: false
    t.string "module_slug", null: false
    t.datetime "updated_at", null: false
    t.index ["module_slug"], name: "index_module_records_on_module_slug"
  end

  create_table "target_mappings", force: :cascade do |t|
    t.string "activity_name", null: false
    t.text "afl_ids", default: "[]", null: false
    t.date "completion_date"
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "created_by_type"
    t.integer "farmer_count", default: 0, null: false
    t.string "fco_id", null: false
    t.string "fco_name"
    t.string "ics_id", null: false
    t.string "ics_name"
    t.string "main_activity_name"
    t.string "month_name", null: false
    t.decimal "target_quantity", precision: 18, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.string "village_id", null: false
    t.string "village_name"
    t.bigint "vrp_ics_mapping_id"
    t.bigint "vrp_id", null: false
    t.index ["created_by_type", "created_by_id"], name: "index_target_mappings_on_creator"
    t.index ["vrp_ics_mapping_id"], name: "index_target_mappings_on_vrp_ics_mapping_id"
    t.index ["vrp_id", "vrp_ics_mapping_id", "month_name", "activity_name"], name: "index_target_mappings_on_scope"
    t.index ["vrp_id"], name: "index_target_mappings_on_vrp_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "age"
    t.string "block"
    t.datetime "created_at", null: false
    t.string "district"
    t.string "email"
    t.string "emergency_no"
    t.string "first_name"
    t.text "full_address"
    t.string "gender"
    t.string "gram_panchayat"
    t.string "ics"
    t.string "last_name"
    t.string "mobile_no"
    t.string "office"
    t.string "office_category"
    t.string "office_name"
    t.string "parent_office"
    t.string "password"
    t.string "person_type"
    t.string "pincode"
    t.string "role"
    t.string "role_name"
    t.string "stakeholder"
    t.string "stakeholder_role"
    t.string "state"
    t.string "status", default: "Active", null: false
    t.string "sub_office_name"
    t.datetime "updated_at", null: false
    t.string "user_management_role"
    t.string "user_name", null: false
    t.string "user_type"
    t.string "village"
    t.index ["email"], name: "index_users_on_email"
    t.index ["mobile_no"], name: "index_users_on_mobile_no"
    t.index ["user_name"], name: "index_users_on_user_name"
  end

  create_table "vrp_bank_masters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_deleted", default: false, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "vrp_ics_mappings", force: :cascade do |t|
    t.text "afl_ids", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "created_by_type"
    t.string "fco_id", null: false
    t.string "fco_name"
    t.string "ics_id", null: false
    t.string "ics_name"
    t.datetime "updated_at", null: false
    t.string "village_id", null: false
    t.string "village_name"
    t.bigint "vrp_id", null: false
    t.index ["created_by_type", "created_by_id"], name: "index_vrp_ics_mappings_on_creator"
    t.index ["vrp_id", "fco_id", "ics_id", "village_id"], name: "index_vrp_ics_mappings_on_mapping_scope", unique: true
    t.index ["vrp_id"], name: "index_vrp_ics_mappings_on_vrp_id"
  end

  create_table "vrp_profiles", force: :cascade do |t|
    t.integer "block_id", null: false
    t.datetime "created_at", null: false
    t.integer "district_id", null: false
    t.integer "gram_panchayat_id", null: false
    t.integer "state_id", null: false
    t.datetime "updated_at", null: false
    t.integer "village_id", null: false
    t.bigint "vrp_id", null: false
    t.index ["vrp_id"], name: "index_vrp_profiles_on_vrp_id"
  end

  create_table "vrp_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_deleted", default: false, null: false
    t.string "type_name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "vrps", force: :cascade do |t|
    t.string "aadhar_no", null: false
    t.string "account_no", null: false
    t.text "address", null: false
    t.datetime "agreement_accepted_at"
    t.text "agreement_signature_data"
    t.string "bank_name"
    t.string "branch", null: false
    t.string "cluster_incharge"
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.date "date_of_birth", null: false
    t.date "date_of_joining", null: false
    t.string "email", null: false
    t.string "emergency_no"
    t.integer "experience_in_years", null: false
    t.string "father_husband_name", null: false
    t.string "fcoc"
    t.integer "gender", null: false
    t.text "gram_panchayat_ids"
    t.text "ics_master_ids"
    t.string "ifsc_code", null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_deleted", default: false, null: false
    t.string "mobile_no", null: false
    t.string "name", null: false
    t.integer "office_detail_id", null: false
    t.string "password"
    t.string "person_type"
    t.text "project_master_ids"
    t.string "role"
    t.string "stakeholder"
    t.string "stakeholder_role"
    t.integer "status", default: 25, null: false
    t.string "to_name"
    t.integer "to_office_detail_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "user_management_role"
    t.string "user_name"
    t.text "village_ids"
    t.bigint "vrp_bank_master_id"
    t.text "vrp_type_ids"
    t.index ["aadhar_no"], name: "index_vrps_on_aadhar_no"
    t.index ["email"], name: "index_vrps_on_email"
    t.index ["mobile_no"], name: "index_vrps_on_mobile_no"
    t.index ["vrp_bank_master_id"], name: "index_vrps_on_vrp_bank_master_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "target_mappings", "vrp_ics_mappings"
  add_foreign_key "target_mappings", "vrps"
  add_foreign_key "vrp_ics_mappings", "vrps"
  add_foreign_key "vrp_profiles", "vrps"
  add_foreign_key "vrps", "vrp_bank_masters"
end
