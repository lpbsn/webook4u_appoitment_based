class AddConfirmedBookingOverlapProtection < ActiveRecord::Migration[8.1]
  CONSTRAINT_NAME = "bookings_confirmed_no_overlapping_intervals_per_enseigne"
  LEGACY_INDEX_NAME = "index_bookings_on_enseigne_and_start_time_confirmed"

  def up
    enable_extension "btree_gist"
    ensure_no_confirmed_overlaps!

    remove_index :bookings, name: LEGACY_INDEX_NAME if index_exists?(:bookings, name: LEGACY_INDEX_NAME)

    execute <<~SQL
      ALTER TABLE bookings
      ADD CONSTRAINT #{CONSTRAINT_NAME}
      EXCLUDE USING gist (
        enseigne_id WITH =,
        tsrange(booking_start_time, booking_end_time, '[)') WITH &&
      )
      WHERE (booking_status = 'confirmed');
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE bookings
      DROP CONSTRAINT IF EXISTS #{CONSTRAINT_NAME};
    SQL

    add_index :bookings,
              [ :enseigne_id, :booking_start_time ],
              unique: true,
              where: "booking_status = 'confirmed'",
              name: LEGACY_INDEX_NAME
  end

  private

  def ensure_no_confirmed_overlaps!
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
      Cannot add confirmed bookings overlap protection: found #{rows.length} conflicting confirmed booking pair(s).
      Resolve overlaps before retrying. Sample pair ids: #{conflict_pairs}
    MSG
  end
end
