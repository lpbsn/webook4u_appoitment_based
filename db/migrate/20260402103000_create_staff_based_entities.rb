class CreateStaffBasedEntities < ActiveRecord::Migration[8.1]
  def change
    create_table :staffs do |t|
      t.references :enseigne, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    create_table :staff_availabilities do |t|
      t.references :staff, null: false, foreign_key: true
      t.integer :day_of_week, null: false
      t.time :opens_at, null: false
      t.time :closes_at, null: false

      t.timestamps
    end
    add_index :staff_availabilities, [ :staff_id, :day_of_week ], name: "index_staff_availabilities_on_staff_and_day"

    create_table :staff_unavailabilities do |t|
      t.references :staff, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false

      t.timestamps
    end
    add_index :staff_unavailabilities, [ :staff_id, :starts_at ], name: "index_staff_unavailabilities_on_staff_and_starts_at"

    create_table :staff_service_capabilities do |t|
      t.references :staff, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true

      t.timestamps
    end
    add_index :staff_service_capabilities, [ :staff_id, :service_id ], unique: true, name: "index_staff_service_capabilities_on_staff_and_service"

    create_table :service_assignment_cursors do |t|
      t.references :service, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
