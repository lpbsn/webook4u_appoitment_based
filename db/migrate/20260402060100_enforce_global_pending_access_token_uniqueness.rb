class EnforceGlobalPendingAccessTokenUniqueness < ActiveRecord::Migration[8.1]
  def up
    ensure_no_duplicate_expired_tokens!
    ensure_no_cross_table_token_collisions!

    remove_index :expired_booking_links, name: "index_expired_booking_links_on_client_and_token"
    add_index :expired_booking_links,
              :pending_access_token,
              unique: true,
              name: "index_expired_booking_links_on_pending_access_token"

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

    execute <<~SQL
      CREATE TRIGGER bookings_global_pending_access_token_uniqueness_trigger
      BEFORE INSERT OR UPDATE OF pending_access_token ON bookings
      FOR EACH ROW
      EXECUTE FUNCTION enforce_global_pending_access_token_uniqueness();
    SQL

    execute <<~SQL
      CREATE TRIGGER expired_booking_links_global_pending_access_token_uniqueness_trigger
      BEFORE INSERT OR UPDATE OF pending_access_token ON expired_booking_links
      FOR EACH ROW
      EXECUTE FUNCTION enforce_global_pending_access_token_uniqueness();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS bookings_global_pending_access_token_uniqueness_trigger ON bookings;
    SQL

    execute <<~SQL
      DROP TRIGGER IF EXISTS expired_booking_links_global_pending_access_token_uniqueness_trigger ON expired_booking_links;
    SQL

    execute <<~SQL
      DROP FUNCTION IF EXISTS enforce_global_pending_access_token_uniqueness();
    SQL

    remove_index :expired_booking_links, name: "index_expired_booking_links_on_pending_access_token"
    add_index :expired_booking_links,
              [ :client_id, :pending_access_token ],
              unique: true,
              name: "index_expired_booking_links_on_client_and_token"
  end

  private

  def ensure_no_duplicate_expired_tokens!
    result = execute(<<~SQL.squish).first
      SELECT COUNT(*) AS duplicate_count
      FROM (
        SELECT pending_access_token
        FROM expired_booking_links
        GROUP BY pending_access_token
        HAVING COUNT(*) > 1
      ) duplicates
    SQL

    duplicate_count = result["duplicate_count"].to_i
    return if duplicate_count.zero?

    sample_tokens = execute(<<~SQL.squish).map { |row| row["pending_access_token"] }
      SELECT pending_access_token
      FROM expired_booking_links
      GROUP BY pending_access_token
      HAVING COUNT(*) > 1
      ORDER BY pending_access_token
      LIMIT 20
    SQL

    raise <<~MESSAGE.squish
      Cannot enforce global pending_access_token uniqueness: found #{duplicate_count} duplicated token(s) in expired_booking_links.
      Sample tokens: #{sample_tokens.join(', ')}.
      Clean the data with a dedicated remediation migration before rerunning.
    MESSAGE
  end

  def ensure_no_cross_table_token_collisions!
    result = execute(<<~SQL.squish).first
      SELECT COUNT(*) AS collision_count
      FROM bookings b
      JOIN expired_booking_links ebl ON ebl.pending_access_token = b.pending_access_token
      WHERE NULLIF(BTRIM(b.pending_access_token), '') IS NOT NULL
    SQL

    collision_count = result["collision_count"].to_i
    return if collision_count.zero?

    sample_booking_ids = execute(<<~SQL.squish).map { |row| row["id"] }
      SELECT b.id
      FROM bookings b
      JOIN expired_booking_links ebl ON ebl.pending_access_token = b.pending_access_token
      WHERE NULLIF(BTRIM(b.pending_access_token), '') IS NOT NULL
      ORDER BY b.id
      LIMIT 20
    SQL

    raise <<~MESSAGE.squish
      Cannot enforce global pending_access_token uniqueness: found #{collision_count} booking(s) colliding with expired_booking_links.
      Sample booking ids: #{sample_booking_ids.join(', ')}.
      Clean the data with a dedicated remediation migration before rerunning.
    MESSAGE
  end
end
