class AddConfirmedRequiresStaffToBookings < ActiveRecord::Migration[8.1]
  CONSTRAINT_NAME = "bookings_confirmed_requires_staff_id"

  def up
    ensure_no_confirmed_without_staff!

    execute <<~SQL
      ALTER TABLE bookings
      ADD CONSTRAINT #{CONSTRAINT_NAME}
      CHECK (booking_status <> 'confirmed' OR staff_id IS NOT NULL);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE bookings
      DROP CONSTRAINT IF EXISTS #{CONSTRAINT_NAME};
    SQL
  end

  private

  def ensure_no_confirmed_without_staff!
    rows = select_rows(<<~SQL.squish)
      SELECT id
      FROM bookings
      WHERE booking_status = 'confirmed'
        AND staff_id IS NULL
      ORDER BY id
      LIMIT 10
    SQL

    return if rows.empty?

    sample_ids = rows.map(&:first).join(", ")
    raise <<~MSG.squish
      Cannot enforce confirmed staff requirement: found #{rows.length} confirmed booking(s) without staff_id.
      Resolve these rows before retrying. Sample ids: #{sample_ids}
    MSG
  end
end
