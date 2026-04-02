class AddConfirmationTokenToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :confirmation_token, :string
    add_index :bookings, :confirmation_token, unique: true
  end
end
