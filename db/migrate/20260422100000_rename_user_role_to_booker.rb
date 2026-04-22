class RenameUserRoleToBooker < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :users, name: "users_role_allowed_values"

    execute <<~SQL
      UPDATE users
      SET role = 'booker'
      WHERE role = 'user'
    SQL

    change_column_default :users, :role, from: "user", to: "booker"

    add_check_constraint :users,
                         "role IN ('admin', 'client_user', 'booker')",
                         name: "users_role_allowed_values"
  end

  def down
    remove_check_constraint :users, name: "users_role_allowed_values"

    execute <<~SQL
      UPDATE users
      SET role = 'user'
      WHERE role = 'booker'
    SQL

    change_column_default :users, :role, from: "booker", to: "user"

    add_check_constraint :users,
                         "role IN ('admin', 'client_user', 'user')",
                         name: "users_role_allowed_values"
  end
end
