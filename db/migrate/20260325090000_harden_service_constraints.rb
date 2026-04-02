class HardenServiceConstraints < ActiveRecord::Migration[8.1]
  def change
    change_column_null :services, :name, false
    change_column_null :services, :duration_minutes, false
    change_column_null :services, :price_cents, false

    add_check_constraint :services, "duration_minutes > 0", name: "services_duration_minutes_positive"
    add_check_constraint :services, "price_cents >= 0", name: "services_price_cents_non_negative"
  end
end
