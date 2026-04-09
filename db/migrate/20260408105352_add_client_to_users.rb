class AddClientToUsers < ActiveRecord::Migration[8.1]
  def up
    add_reference :users, :client, null: true, foreign_key: true

    client_id = execute("SELECT id FROM clients ORDER BY id ASC LIMIT 1").first["id"]
    raise "No client found to backfill users.client_id" unless client_id

    execute <<~SQL
      UPDATE users
      SET client_id = #{client_id}
      WHERE client_id IS NULL
    SQL

    change_column_null :users, :client_id, false

    remove_index :users, :email
    add_index :users, [ :client_id, :email ], unique: true
  end

  def down
    remove_index :users, [ :client_id, :email ]
    add_index :users, :email, unique: true

    remove_reference :users, :client, foreign_key: true
  end
end
