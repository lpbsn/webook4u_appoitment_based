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

ActiveRecord::Schema[8.1].define(version: 2026_04_03_113000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "bookings", force: :cascade do |t|
    t.datetime "booking_end_time", null: false
    t.datetime "booking_expires_at"
    t.datetime "booking_start_time", null: false
    t.string "booking_status", null: false
    t.bigint "client_id", null: false
    t.string "confirmation_token"
    t.datetime "created_at", null: false
    t.string "customer_email"
    t.string "customer_first_name"
    t.string "customer_last_name"
    t.bigint "enseigne_id", null: false
    t.string "pending_access_token"
    t.bigint "service_id", null: false
    t.bigint "staff_id"
    t.string "stripe_payment_intent"
    t.string "stripe_session_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["client_id"], name: "index_bookings_on_client_id"
    t.index ["confirmation_token"], name: "index_bookings_on_confirmation_token", unique: true
    t.index ["enseigne_id"], name: "index_bookings_on_enseigne_id"
    t.index ["pending_access_token"], name: "index_bookings_on_pending_access_token", unique: true
    t.index ["service_id"], name: "index_bookings_on_service_id"
    t.index ["staff_id"], name: "index_bookings_on_staff_id"
    t.index ["user_id"], name: "index_bookings_on_user_id"
    t.check_constraint "booking_end_time > booking_start_time", name: "bookings_end_time_after_start_time"
    t.check_constraint "booking_status::text <> 'confirmed'::text OR NULLIF(btrim(confirmation_token::text), ''::text) IS NOT NULL", name: "bookings_confirmed_requires_confirmation_token"
    t.check_constraint "booking_status::text <> 'confirmed'::text OR NULLIF(btrim(customer_email::text), ''::text) IS NOT NULL", name: "bookings_confirmed_requires_customer_email"
    t.check_constraint "booking_status::text <> 'confirmed'::text OR NULLIF(btrim(customer_first_name::text), ''::text) IS NOT NULL", name: "bookings_confirmed_requires_customer_first_name"
    t.check_constraint "booking_status::text <> 'confirmed'::text OR NULLIF(btrim(customer_last_name::text), ''::text) IS NOT NULL", name: "bookings_confirmed_requires_customer_last_name"
    t.check_constraint "booking_status::text <> 'confirmed'::text OR staff_id IS NOT NULL", name: "bookings_confirmed_requires_staff_id"
    t.check_constraint "booking_status::text <> 'pending'::text OR NULLIF(btrim(pending_access_token::text), ''::text) IS NOT NULL", name: "bookings_pending_requires_pending_access_token"
    t.check_constraint "booking_status::text <> 'pending'::text OR booking_expires_at IS NOT NULL", name: "bookings_pending_requires_booking_expires_at"
    t.check_constraint "booking_status::text = ANY (ARRAY['pending'::character varying, 'confirmed'::character varying, 'failed'::character varying]::text[])", name: "bookings_status_allowed_values"
    t.exclusion_constraint "staff_id WITH =, tsrange(booking_start_time, booking_end_time, '[)'::text) WITH &&", where: "((booking_status)::text = 'confirmed'::text) AND (staff_id IS NOT NULL)", using: :gist, name: "bookings_confirmed_no_overlapping_intervals_per_staff"
  end

  create_table "clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_clients_on_slug", unique: true
    t.check_constraint "NULLIF(btrim(name::text), ''::text) IS NOT NULL", name: "clients_name_not_blank"
  end

  create_table "enseigne_opening_hours", force: :cascade do |t|
    t.time "closes_at", null: false
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.bigint "enseigne_id", null: false
    t.time "opens_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enseigne_id", "day_of_week", "opens_at", "closes_at"], name: "index_enseigne_opening_hours_on_exact_interval_per_day", unique: true
    t.index ["enseigne_id", "day_of_week"], name: "index_enseigne_opening_hours_on_enseigne_and_day"
    t.index ["enseigne_id"], name: "index_enseigne_opening_hours_on_enseigne_id"
    t.check_constraint "opens_at < closes_at", name: "enseigne_opening_hours_opens_before_closes"
    t.exclusion_constraint "enseigne_id WITH =, day_of_week WITH =, int4range((EXTRACT(epoch FROM opens_at))::integer, (EXTRACT(epoch FROM closes_at))::integer, '[)'::text) WITH &&", using: :gist, name: "enseigne_opening_hours_no_overlapping_intervals_per_day"
  end

  create_table "enseignes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.string "full_address"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_enseignes_on_client_id"
  end

  create_table "expired_booking_links", force: :cascade do |t|
    t.date "booking_date", null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.bigint "enseigne_id"
    t.datetime "expired_at", null: false
    t.string "pending_access_token", null: false
    t.bigint "service_id"
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_expired_booking_links_on_client_id"
    t.index ["expired_at"], name: "index_expired_booking_links_on_expired_at"
    t.index ["pending_access_token"], name: "index_expired_booking_links_on_pending_access_token", unique: true
  end

  create_table "service_assignment_cursors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "last_confirmed_staff_id"
    t.bigint "service_id", null: false
    t.datetime "updated_at", null: false
    t.index ["last_confirmed_staff_id"], name: "index_service_assignment_cursors_on_last_confirmed_staff_id"
    t.index ["service_id"], name: "index_service_assignment_cursors_on_service_id", unique: true
  end

  create_table "services", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_minutes", null: false
    t.bigint "enseigne_id", null: false
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["enseigne_id"], name: "index_services_on_enseigne_id"
    t.check_constraint "duration_minutes > 0", name: "services_duration_minutes_positive"
    t.check_constraint "price_cents >= 0", name: "services_price_cents_non_negative"
  end

  create_table "staff_availabilities", force: :cascade do |t|
    t.time "closes_at", null: false
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.time "opens_at", null: false
    t.bigint "staff_id", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_id", "day_of_week"], name: "index_staff_availabilities_on_staff_and_day"
    t.index ["staff_id"], name: "index_staff_availabilities_on_staff_id"
  end

  create_table "staff_service_capabilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "service_id", null: false
    t.bigint "staff_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id"], name: "index_staff_service_capabilities_on_service_id"
    t.index ["staff_id", "service_id"], name: "index_staff_service_capabilities_on_staff_and_service", unique: true
    t.index ["staff_id"], name: "index_staff_service_capabilities_on_staff_id"
  end

  create_table "staff_unavailabilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.bigint "staff_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_id", "starts_at"], name: "index_staff_unavailabilities_on_staff_and_starts_at"
    t.index ["staff_id"], name: "index_staff_unavailabilities_on_staff_id"
  end

  create_table "staffs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "enseigne_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["enseigne_id"], name: "index_staffs_on_enseigne_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "bookings", "clients"
  add_foreign_key "bookings", "enseignes"
  add_foreign_key "bookings", "services"
  add_foreign_key "bookings", "staffs"
  add_foreign_key "bookings", "users"
  add_foreign_key "enseigne_opening_hours", "enseignes"
  add_foreign_key "enseignes", "clients"
  add_foreign_key "expired_booking_links", "clients"
  add_foreign_key "service_assignment_cursors", "services"
  add_foreign_key "service_assignment_cursors", "staffs", column: "last_confirmed_staff_id", on_delete: :nullify
  add_foreign_key "services", "enseignes"
  add_foreign_key "staff_availabilities", "staffs"
  add_foreign_key "staff_service_capabilities", "services"
  add_foreign_key "staff_service_capabilities", "staffs"
  add_foreign_key "staff_unavailabilities", "staffs"
  add_foreign_key "staffs", "enseignes"
end
