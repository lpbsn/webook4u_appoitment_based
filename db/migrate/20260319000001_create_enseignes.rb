class CreateEnseignes < ActiveRecord::Migration[8.1]
  def change
    create_table :enseignes do |t|
      t.references :client, null: false, foreign_key: true
      t.string :name, null: false
      t.string :full_address
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
