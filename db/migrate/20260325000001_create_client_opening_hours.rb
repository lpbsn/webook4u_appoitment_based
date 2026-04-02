class CreateClientOpeningHours < ActiveRecord::Migration[8.1]
  def change
    create_table :client_opening_hours do |t|
      t.references :client, null: false, foreign_key: true
      t.integer :day_of_week, null: false
      t.time :opens_at, null: false
      t.time :closes_at, null: false

      t.timestamps
    end

    add_index :client_opening_hours, [ :client_id, :day_of_week ], name: "index_client_opening_hours_on_client_and_day"
  end
end
