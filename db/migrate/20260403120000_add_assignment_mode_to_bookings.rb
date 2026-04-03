class AddAssignmentModeToBookings < ActiveRecord::Migration[8.1]
  def up
    add_column :bookings, :assignment_mode, :string, default: "automatic"

    execute <<~SQL
      UPDATE bookings
      SET assignment_mode = 'automatic'
      WHERE assignment_mode IS NULL
    SQL

    change_column_null :bookings, :assignment_mode, false

    add_check_constraint(
      :bookings,
      "assignment_mode IN ('automatic', 'specific_staff')",
      name: "bookings_assignment_mode_allowed_values"
    )
  end

  def down
    remove_check_constraint :bookings, name: "bookings_assignment_mode_allowed_values"
    remove_column :bookings, :assignment_mode
  end
end
