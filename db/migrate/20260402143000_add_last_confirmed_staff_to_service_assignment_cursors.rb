class AddLastConfirmedStaffToServiceAssignmentCursors < ActiveRecord::Migration[8.1]
  def change
    add_reference :service_assignment_cursors,
                  :last_confirmed_staff,
                  null: true,
                  foreign_key: { to_table: :staffs, on_delete: :nullify }
  end
end
