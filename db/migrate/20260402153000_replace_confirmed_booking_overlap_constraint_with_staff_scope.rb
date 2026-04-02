class ReplaceConfirmedBookingOverlapConstraintWithStaffScope < ActiveRecord::Migration[8.1]
  OLD_CONSTRAINT_NAME = "bookings_confirmed_no_overlapping_intervals_per_enseigne"
  NEW_CONSTRAINT_NAME = "bookings_confirmed_no_overlapping_intervals_per_staff"

  def up
    enable_extension "btree_gist"
    ensure_no_confirmed_staff_overlaps!

    execute <<~SQL
      ALTER TABLE bookings
      DROP CONSTRAINT IF EXISTS #{OLD_CONSTRAINT_NAME};
    SQL

    execute <<~SQL
      ALTER TABLE bookings
      DROP CONSTRAINT IF EXISTS #{NEW_CONSTRAINT_NAME};
    SQL

    execute <<~SQL
      ALTER TABLE bookings
      ADD CONSTRAINT #{NEW_CONSTRAINT_NAME}
      EXCLUDE USING gist (
        staff_id WITH =,
        tsrange(booking_start_time, booking_end_time, '[)') WITH &&
      )
      WHERE (booking_status = 'confirmed' AND staff_id IS NOT NULL);
    SQL
  end

  def down
    ensure_no_confirmed_enseigne_overlaps!

    execute <<~SQL
      ALTER TABLE bookings
      DROP CONSTRAINT IF EXISTS #{NEW_CONSTRAINT_NAME};
    SQL

    execute <<~SQL
      ALTER TABLE bookings
      DROP CONSTRAINT IF EXISTS #{OLD_CONSTRAINT_NAME};
    SQL

    execute <<~SQL
      ALTER TABLE bookings
      ADD CONSTRAINT #{OLD_CONSTRAINT_NAME}
      EXCLUDE USING gist (
        enseigne_id WITH =,
        tsrange(booking_start_time, booking_end_time, '[)') WITH &&
      )
      WHERE (booking_status = 'confirmed');
    SQL
  end

  private

  def ensure_no_confirmed_staff_overlaps!
    rows = select_rows(<<~SQL.squish)
      SELECT b1.id, b2.id
      FROM bookings b1
      JOIN bookings b2
        ON b1.id < b2.id
       AND b1.staff_id IS NOT NULL
       AND b1.staff_id = b2.staff_id
       AND b1.booking_status = 'confirmed'
       AND b2.booking_status = 'confirmed'
       AND tsrange(b1.booking_start_time, b1.booking_end_time, '[)')
           && tsrange(b2.booking_start_time, b2.booking_end_time, '[)')
      ORDER BY b1.id, b2.id
      LIMIT 10
    SQL

    return if rows.empty?

    conflict_pairs = rows.map { |left_id, right_id| "#{left_id}/#{right_id}" }.join(", ")
    raise <<~MSG.squish
      Cannot scope confirmed bookings overlap protection by staff: found #{rows.length} conflicting confirmed booking pair(s).
      Resolve overlaps before retrying. Sample pair ids: #{conflict_pairs}
    MSG
  end

  def ensure_no_confirmed_enseigne_overlaps!
    rows = select_rows(<<~SQL.squish)
      SELECT b1.id, b2.id
      FROM bookings b1
      JOIN bookings b2
        ON b1.id < b2.id
       AND b1.enseigne_id = b2.enseigne_id
       AND b1.booking_status = 'confirmed'
       AND b2.booking_status = 'confirmed'
       AND tsrange(b1.booking_start_time, b1.booking_end_time, '[)')
           && tsrange(b2.booking_start_time, b2.booking_end_time, '[)')
      ORDER BY b1.id, b2.id
      LIMIT 10
    SQL

    return if rows.empty?

    conflict_pairs = rows.map { |left_id, right_id| "#{left_id}/#{right_id}" }.join(", ")
    raise <<~MSG.squish
      Cannot restore enseigne-scoped confirmed overlap protection: found #{rows.length} conflicting confirmed booking pair(s).
      Resolve overlaps before retrying. Sample pair ids: #{conflict_pairs}
    MSG
  end
end
