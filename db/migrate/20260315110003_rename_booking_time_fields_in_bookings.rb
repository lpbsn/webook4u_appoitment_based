class RenameBookingTimeFieldsInBookings < ActiveRecord::Migration[8.1]
  def change
    rename_column :bookings, :start_time, :booking_start_time
    rename_column :bookings, :end_time, :booking_end_time
    rename_column :bookings, :expires_at, :booking_expires_at
  end
end
