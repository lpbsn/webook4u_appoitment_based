class CreateFinalStaffBasedSchema < ActiveRecord::Migration[8.1]
  def up
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    create_clients!
    create_enseignes!
    create_enseigne_opening_hours!
    create_services!
    create_staffs!
    create_staff_availabilities!
    create_staff_unavailabilities!
    create_staff_service_capabilities!
    create_service_assignment_cursors!
    create_users!
    create_bookings!
    create_expired_booking_links!

    add_foreign_keys!
    create_functions!
    create_triggers!
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Final baseline migration cannot be rolled back."
  end

  private

  def create_clients!
    create_table :clients do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps

      t.index :slug, unique: true
      t.check_constraint "NULLIF(BTRIM(name), '') IS NOT NULL", name: "clients_name_not_blank"
    end
  end

  def create_enseignes!
    create_table :enseignes do |t|
      t.references :client, null: false
      t.string :name, null: false
      t.string :full_address
      t.boolean :active, null: false, default: true
      t.timestamps
    end
  end

  def create_enseigne_opening_hours!
    create_table :enseigne_opening_hours do |t|
      t.references :enseigne, null: false
      t.integer :day_of_week, null: false
      t.time :opens_at, null: false
      t.time :closes_at, null: false
      t.timestamps

      t.index [:enseigne_id, :day_of_week], name: "index_enseigne_opening_hours_on_enseigne_and_day"
      t.index [:enseigne_id, :day_of_week, :opens_at, :closes_at],
        unique: true,
        name: "index_enseigne_opening_hours_on_exact_interval_per_day"
      t.check_constraint "opens_at < closes_at", name: "enseigne_opening_hours_opens_before_closes"
      t.exclusion_constraint(
        "enseigne_id WITH =, day_of_week WITH =, int4range((EXTRACT(EPOCH FROM opens_at))::integer, (EXTRACT(EPOCH FROM closes_at))::integer, '[)') WITH &&",
        using: :gist,
        name: "enseigne_opening_hours_no_overlapping_intervals_per_day"
      )
    end
  end

  def create_services!
    create_table :services do |t|
      t.string :name, null: false
      t.integer :duration_minutes, null: false
      t.integer :price_cents, null: false
      t.references :enseigne, null: false
      t.timestamps

      t.check_constraint "duration_minutes > 0", name: "services_duration_minutes_positive"
      t.check_constraint "price_cents >= 0", name: "services_price_cents_non_negative"
    end
  end

  def create_staffs!
    create_table :staffs do |t|
      t.references :enseigne, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
  end

  def create_staff_availabilities!
    create_table :staff_availabilities do |t|
      t.references :staff, null: false
      t.integer :day_of_week, null: false
      t.time :opens_at, null: false
      t.time :closes_at, null: false
      t.timestamps

      t.index [:staff_id, :day_of_week], name: "index_staff_availabilities_on_staff_and_day"
    end
  end

  def create_staff_unavailabilities!
    create_table :staff_unavailabilities do |t|
      t.references :staff, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.timestamps

      t.index [:staff_id, :starts_at], name: "index_staff_unavailabilities_on_staff_and_starts_at"
    end
  end

  def create_staff_service_capabilities!
    create_table :staff_service_capabilities do |t|
      t.references :staff, null: false
      t.references :service, null: false
      t.timestamps

      t.index [:staff_id, :service_id], unique: true, name: "index_staff_service_capabilities_on_staff_and_service"
    end
  end

  def create_service_assignment_cursors!
    create_table :service_assignment_cursors do |t|
      t.references :service, null: false, index: { unique: true }
      t.references :last_confirmed_staff, foreign_key: { to_table: :staffs, on_delete: :nullify }
      t.timestamps
    end
  end

  def create_users!
    create_table :users do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
  end

  def create_bookings!
    create_table :bookings do |t|
      t.references :client, null: false
      t.references :service, null: false
      t.string :customer_email
      t.datetime :booking_start_time, null: false
      t.datetime :booking_end_time, null: false
      t.string :booking_status, null: false
      t.datetime :booking_expires_at
      t.string :stripe_session_id
      t.string :stripe_payment_intent
      t.string :customer_first_name
      t.string :customer_last_name
      t.string :confirmation_token
      t.references :enseigne, null: false
      t.string :pending_access_token
      t.references :staff
      t.references :user
      t.timestamps

      t.index :confirmation_token, unique: true
      t.index :pending_access_token, unique: true
      t.check_constraint "booking_end_time > booking_start_time", name: "bookings_end_time_after_start_time"
      t.check_constraint(
        "booking_status <> 'confirmed' OR NULLIF(BTRIM(confirmation_token), '') IS NOT NULL",
        name: "bookings_confirmed_requires_confirmation_token"
      )
      t.check_constraint(
        "booking_status <> 'confirmed' OR NULLIF(BTRIM(customer_email), '') IS NOT NULL",
        name: "bookings_confirmed_requires_customer_email"
      )
      t.check_constraint(
        "booking_status <> 'confirmed' OR NULLIF(BTRIM(customer_first_name), '') IS NOT NULL",
        name: "bookings_confirmed_requires_customer_first_name"
      )
      t.check_constraint(
        "booking_status <> 'confirmed' OR NULLIF(BTRIM(customer_last_name), '') IS NOT NULL",
        name: "bookings_confirmed_requires_customer_last_name"
      )
      t.check_constraint(
        "booking_status <> 'confirmed' OR staff_id IS NOT NULL",
        name: "bookings_confirmed_requires_staff_id"
      )
      t.check_constraint(
        "booking_status <> 'pending' OR NULLIF(BTRIM(pending_access_token), '') IS NOT NULL",
        name: "bookings_pending_requires_pending_access_token"
      )
      t.check_constraint(
        "booking_status <> 'pending' OR booking_expires_at IS NOT NULL",
        name: "bookings_pending_requires_booking_expires_at"
      )
      t.check_constraint(
        "booking_status IN ('pending', 'confirmed', 'failed')",
        name: "bookings_status_allowed_values"
      )
      t.exclusion_constraint(
        "staff_id WITH =, tsrange(booking_start_time, booking_end_time, '[)') WITH &&",
        where: "(booking_status = 'confirmed') AND (staff_id IS NOT NULL)",
        using: :gist,
        name: "bookings_confirmed_no_overlapping_intervals_per_staff"
      )
    end
  end

  def create_expired_booking_links!
    create_table :expired_booking_links do |t|
      t.references :client, null: false
      t.string :pending_access_token, null: false
      t.bigint :enseigne_id
      t.bigint :service_id
      t.date :booking_date, null: false
      t.datetime :expired_at, null: false
      t.timestamps
    end

    add_index :expired_booking_links, :pending_access_token, unique: true
    add_index :expired_booking_links, :expired_at
  end

  def add_foreign_keys!
    add_foreign_key :bookings, :clients
    add_foreign_key :bookings, :enseignes
    add_foreign_key :bookings, :services
    add_foreign_key :bookings, :staffs
    add_foreign_key :bookings, :users
    add_foreign_key :enseigne_opening_hours, :enseignes
    add_foreign_key :enseignes, :clients
    add_foreign_key :expired_booking_links, :clients
    add_foreign_key :service_assignment_cursors, :services
    add_foreign_key :services, :enseignes
    add_foreign_key :staff_availabilities, :staffs
    add_foreign_key :staff_service_capabilities, :services
    add_foreign_key :staff_service_capabilities, :staffs
    add_foreign_key :staff_unavailabilities, :staffs
    add_foreign_key :staffs, :enseignes
  end

  def create_functions!
    execute <<~SQL
      CREATE OR REPLACE FUNCTION enforce_bookings_client_consistency()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        service_enseigne_id bigint;
        staff_enseigne_id bigint;
        enseigne_client_id bigint;
      BEGIN
        SELECT enseigne_id INTO service_enseigne_id
        FROM services
        WHERE id = NEW.service_id;

        IF service_enseigne_id IS NOT NULL AND service_enseigne_id <> NEW.enseigne_id THEN
          RAISE EXCEPTION 'bookings.enseigne_id must match services.enseigne_id'
            USING ERRCODE = '23514';
        END IF;

        IF NEW.staff_id IS NOT NULL THEN
          SELECT enseigne_id INTO staff_enseigne_id
          FROM staffs
          WHERE id = NEW.staff_id;

          IF staff_enseigne_id IS NOT NULL AND staff_enseigne_id <> NEW.enseigne_id THEN
            RAISE EXCEPTION 'bookings.enseigne_id must match staffs.enseigne_id'
              USING ERRCODE = '23514';
          END IF;
        END IF;

        SELECT client_id INTO enseigne_client_id
        FROM enseignes
        WHERE id = NEW.enseigne_id;

        IF enseigne_client_id IS NOT NULL AND enseigne_client_id <> NEW.client_id THEN
          RAISE EXCEPTION 'bookings.client_id must match enseignes.client_id'
            USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE OR REPLACE FUNCTION enforce_global_pending_access_token_uniqueness()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NULLIF(BTRIM(NEW.pending_access_token), '') IS NULL THEN
          RETURN NEW;
        END IF;

        IF TG_TABLE_NAME = 'bookings' THEN
          IF EXISTS (
            SELECT 1
            FROM expired_booking_links ebl
            WHERE ebl.pending_access_token = NEW.pending_access_token
          ) THEN
            RAISE EXCEPTION 'pending_access_token must be globally unique across bookings and expired_booking_links'
              USING ERRCODE = '23505';
          END IF;
        ELSIF TG_TABLE_NAME = 'expired_booking_links' THEN
          IF EXISTS (
            SELECT 1
            FROM bookings b
            WHERE b.pending_access_token = NEW.pending_access_token
          ) THEN
            RAISE EXCEPTION 'pending_access_token must be globally unique across bookings and expired_booking_links'
              USING ERRCODE = '23505';
          END IF;
        END IF;

        RETURN NEW;
      END;
      $$;
    SQL
  end

  def create_triggers!
    execute <<~SQL
      CREATE TRIGGER bookings_client_consistency_trigger
      BEFORE INSERT OR UPDATE ON bookings
      FOR EACH ROW
      EXECUTE FUNCTION enforce_bookings_client_consistency();
    SQL

    execute <<~SQL
      CREATE TRIGGER bookings_global_pending_access_token_uniqueness_trigger
      BEFORE INSERT OR UPDATE OF pending_access_token ON bookings
      FOR EACH ROW
      EXECUTE FUNCTION enforce_global_pending_access_token_uniqueness();
    SQL

    execute <<~SQL
      CREATE TRIGGER expired_booking_links_global_pending_access_token_uniqueness_tr
      BEFORE INSERT OR UPDATE OF pending_access_token ON expired_booking_links
      FOR EACH ROW
      EXECUTE FUNCTION enforce_global_pending_access_token_uniqueness();
    SQL
  end
end
