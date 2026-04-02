class RemoveConfirmationEmailSentAtFromBookings < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:bookings, :confirmation_email_sent_at)

    remove_column :bookings, :confirmation_email_sent_at, :datetime, precision: 6
  end

  def down
    return if column_exists?(:bookings, :confirmation_email_sent_at)

    add_column :bookings, :confirmation_email_sent_at, :datetime, precision: 6
  end
end
