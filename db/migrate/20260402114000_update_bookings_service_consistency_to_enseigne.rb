class UpdateBookingsServiceConsistencyToEnseigne < ActiveRecord::Migration[8.1]
  def up
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

  def down
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
  end
end
