class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.references :client, null: false, foreign_key: true
      t.string :name
      t.integer :duration_minutes
      t.integer :price_cents

      t.timestamps
    end
  end
end
