class AddEnseigneToBookings < ActiveRecord::Migration[8.1]
  def change
    add_reference :bookings, :enseigne, foreign_key: true
  end
end
