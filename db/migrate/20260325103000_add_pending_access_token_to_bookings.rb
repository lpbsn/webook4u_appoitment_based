class AddPendingAccessTokenToBookings < ActiveRecord::Migration[8.1]
  class Booking < ApplicationRecord
    self.table_name = "bookings"
  end

  def up
    add_column :bookings, :pending_access_token, :string
    add_index :bookings, :pending_access_token, unique: true

    backfill_pending_access_tokens!
  end

  def down
    remove_index :bookings, :pending_access_token
    remove_column :bookings, :pending_access_token
  end

  private

  def backfill_pending_access_tokens!
    Booking.reset_column_information

    Booking.where(booking_status: "pending", pending_access_token: nil).find_each do |booking|
      booking.update_columns(pending_access_token: unique_token)
    end
  end

  def unique_token
    loop do
      token = SecureRandom.urlsafe_base64(24)
      break token unless Booking.exists?(pending_access_token: token)
    end
  end
end
