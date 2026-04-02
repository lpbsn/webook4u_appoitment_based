class AddBookingsClientConsistencyTrigger < ActiveRecord::Migration[8.1]
  def up
    ensure_no_cross_table_inconsistencies!

    execute <<~SQL
      CREATE OR REPLACE FUNCTION enforce_bookings_client_consistency()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        service_client_id bigint;
        enseigne_client_id bigint;
      BEGIN
        SELECT client_id INTO service_client_id
        FROM services
        WHERE id = NEW.service_id;

        IF service_client_id IS NOT NULL AND service_client_id <> NEW.client_id THEN
          RAISE EXCEPTION 'bookings.client_id must match services.client_id'
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

    execute <<~SQL
      CREATE TRIGGER bookings_client_consistency_trigger
      BEFORE INSERT OR UPDATE ON bookings
      FOR EACH ROW
      EXECUTE FUNCTION enforce_bookings_client_consistency();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS bookings_client_consistency_trigger ON bookings;
    SQL

    execute <<~SQL
      DROP FUNCTION IF EXISTS enforce_bookings_client_consistency();
    SQL
  end

  private

  def ensure_no_cross_table_inconsistencies!
    result = execute(<<~SQL.squish).first
      SELECT COUNT(*) AS inconsistent_count
      FROM bookings b
      JOIN services s ON s.id = b.service_id
      JOIN enseignes e ON e.id = b.enseigne_id
      WHERE b.client_id <> s.client_id
         OR b.client_id <> e.client_id
    SQL

    inconsistent_count = result["inconsistent_count"].to_i
    return if inconsistent_count.zero?

    sample_ids = execute(<<~SQL.squish).map { |row| row["id"] }
      SELECT b.id
      FROM bookings b
      JOIN services s ON s.id = b.service_id
      JOIN enseignes e ON e.id = b.enseigne_id
      WHERE b.client_id <> s.client_id
         OR b.client_id <> e.client_id
      ORDER BY b.id
      LIMIT 20
    SQL

    raise <<~MESSAGE.squish
      Cannot add bookings client consistency trigger: found #{inconsistent_count} inconsistent row(s) in bookings.
      Sample booking ids: #{sample_ids.join(", ")}.
      Clean the data with a dedicated remediation migration before rerunning.
    MESSAGE
  end
end
