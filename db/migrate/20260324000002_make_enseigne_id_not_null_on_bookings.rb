class MakeEnseigneIdNotNullOnBookings < ActiveRecord::Migration[8.1]
  def change
    change_column_null :bookings, :enseigne_id, false
  end
end
