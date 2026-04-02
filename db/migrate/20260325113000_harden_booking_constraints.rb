class HardenBookingConstraints < ActiveRecord::Migration[8.1]
  VALID_STATUSES = %w[pending confirmed failed].freeze

  def up
    ensure_no_invalid_bookings!

    change_column_null :bookings, :booking_start_time, false
    change_column_null :bookings, :booking_end_time, false
    change_column_null :bookings, :booking_status, false

    add_check_constraint :bookings,
                         "booking_status IN ('pending', 'confirmed', 'failed')",
                         name: "bookings_status_allowed_values"
    add_check_constraint :bookings,
                         "booking_end_time > booking_start_time",
                         name: "bookings_end_time_after_start_time"
  end

  def down
    remove_check_constraint :bookings, name: "bookings_end_time_after_start_time"
    remove_check_constraint :bookings, name: "bookings_status_allowed_values"

    change_column_null :bookings, :booking_status, true
    change_column_null :bookings, :booking_end_time, true
    change_column_null :bookings, :booking_start_time, true
  end

  private

  def ensure_no_invalid_bookings!
    invalid_scope = execute(<<~SQL.squish)
      SELECT id
      FROM bookings
      WHERE booking_start_time IS NULL
         OR booking_end_time IS NULL
         OR booking_status IS NULL
         OR booking_status NOT IN ('pending', 'confirmed', 'failed')
         OR booking_end_time <= booking_start_time
      LIMIT 5
    SQL

    return if invalid_scope.none?

    invalid_ids = invalid_scope.map { |row| row["id"] }

    raise <<~MESSAGE.squish
      Cannot harden bookings constraints: found invalid existing rows in bookings
      (sample ids: #{invalid_ids.join(", ")}). Clean the data before running this migration.
    MESSAGE
  end
end
