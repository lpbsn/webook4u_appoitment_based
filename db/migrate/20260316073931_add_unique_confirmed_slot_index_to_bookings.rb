class AddUniqueConfirmedSlotIndexToBookings < ActiveRecord::Migration[8.1]
  def change
    add_index :bookings,
              [ :client_id, :booking_start_time ],
              unique: true,
              where: "booking_status = 'confirmed'",
              name: "index_bookings_on_client_and_start_time_confirmed"
  end
end
