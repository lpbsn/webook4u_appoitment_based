class AddStaffToBookings < ActiveRecord::Migration[8.1]
  def change
    add_reference :bookings, :staff, null: true, foreign_key: true
  end
end
