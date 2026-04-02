class ReplaceConfirmedBookingUniquenessScope < ActiveRecord::Migration[8.1]
  def change
    add_index :bookings,
              [ :enseigne_id, :booking_start_time ],
              unique: true,
              where: "booking_status = 'confirmed'",
              name: "index_bookings_on_enseigne_and_start_time_confirmed"

    remove_index :bookings, name: "index_bookings_on_client_and_start_time_confirmed"
  end
end
