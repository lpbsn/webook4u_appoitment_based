class RemoveOldNameFieldsFromBookings < ActiveRecord::Migration[8.1]
  def change
    remove_column :bookings, :customer_name, :string
    remove_column :bookings, :first_name, :string
    remove_column :bookings, :last_name, :string
  end
end
