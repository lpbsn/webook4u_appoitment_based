class AddCustomerFirstNameAndLastNameToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :customer_first_name, :string
    add_column :bookings, :customer_last_name, :string
  end
end
