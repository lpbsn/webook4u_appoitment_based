class AddRoleAndActiveToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :string, null: false, default: "user"
    add_column :users, :active, :boolean, null: false, default: true

    change_column_null :users, :client_id, true

    execute <<~SQL
      UPDATE users
      SET role = 'user'
      WHERE role IS NULL
    SQL

    remove_index :users, [ :client_id, :email ]
    add_index :users, :email, unique: true

    add_check_constraint :users,
                         "role IN ('admin', 'client_user', 'user')",
                         name: "users_role_allowed_values"
    add_check_constraint :users,
                         "(role <> 'admin') OR client_id IS NULL",
                         name: "users_admin_without_client"
    add_check_constraint :users,
                         "(role <> 'client_user') OR client_id IS NOT NULL",
                         name: "users_client_user_requires_client"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Role and active introduction is not reversible safely."
  end
end
