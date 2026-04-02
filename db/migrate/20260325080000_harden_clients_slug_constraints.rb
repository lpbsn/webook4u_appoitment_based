class HardenClientsSlugConstraints < ActiveRecord::Migration[8.1]
  def change
    change_column_null :clients, :slug, false
    add_index :clients, :slug, unique: true
  end
end
