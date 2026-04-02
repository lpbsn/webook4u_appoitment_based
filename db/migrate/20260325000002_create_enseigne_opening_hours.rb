class CreateEnseigneOpeningHours < ActiveRecord::Migration[8.1]
  def change
    create_table :enseigne_opening_hours do |t|
      t.references :enseigne, null: false, foreign_key: true
      t.integer :day_of_week, null: false
      t.time :opens_at, null: false
      t.time :closes_at, null: false

      t.timestamps
    end

    add_index :enseigne_opening_hours, [ :enseigne_id, :day_of_week ], name: "index_enseigne_opening_hours_on_enseigne_and_day"
  end
end
