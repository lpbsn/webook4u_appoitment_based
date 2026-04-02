class EnforceBookingsCrossTableConsistency < ActiveRecord::Migration[8.1]
  def up
    ensure_no_staff_consistency_violations!

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
  end

  def down
    execute <<~SQL
      CREATE OR REPLACE FUNCTION enforce_bookings_client_consistency()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        service_enseigne_id bigint;
        enseigne_client_id bigint;
      BEGIN
        SELECT enseigne_id INTO service_enseigne_id
        FROM services
        WHERE id = NEW.service_id;

        IF service_enseigne_id IS NOT NULL AND service_enseigne_id <> NEW.enseigne_id THEN
          RAISE EXCEPTION 'bookings.enseigne_id must match services.enseigne_id'
            USING ERRCODE = '23514';
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
  end

  private

  def ensure_no_staff_consistency_violations!
    result = execute(<<~SQL.squish).first
      SELECT COUNT(*) AS inconsistent_count
      FROM bookings b
      LEFT JOIN staffs stf ON stf.id = b.staff_id
      WHERE b.staff_id IS NOT NULL
        AND stf.enseigne_id <> b.enseigne_id
    SQL

    inconsistent_count = result.fetch("inconsistent_count").to_i
    return if inconsistent_count.zero?

    sample_ids = execute(<<~SQL.squish).map { |row| row.fetch("id") }
      SELECT b.id
      FROM bookings b
      LEFT JOIN staffs stf ON stf.id = b.staff_id
      WHERE b.staff_id IS NOT NULL
        AND stf.enseigne_id <> b.enseigne_id
      ORDER BY b.id
      LIMIT 20
    SQL

    raise <<~MESSAGE.squish
      Cannot enforce bookings cross-table consistency trigger: found #{inconsistent_count} staff mismatch row(s) in bookings.
      Sample booking ids: #{sample_ids.join(", ")}.
      Clean the data with a dedicated remediation migration before rerunning.
    MESSAGE
  end
end
