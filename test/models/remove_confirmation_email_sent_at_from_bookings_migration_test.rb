require "test_helper"
require Rails.root.join("db/migrate/20260402093113_remove_confirmation_email_sent_at_from_bookings")

class RemoveConfirmationEmailSentAtFromBookingsMigrationTest < SchemaMutationMigrationTestCase
  def setup
    @migration = RemoveConfirmationEmailSentAtFromBookings.new
  end

  test "migration removes and restores confirmation_email_sent_at on bookings" do
    @migration.down
    Booking.reset_column_information

    assert bookings_columns.include?("confirmation_email_sent_at")

    @migration.up
    Booking.reset_column_information

    assert_not bookings_columns.include?("confirmation_email_sent_at")

    @migration.down
    Booking.reset_column_information

    assert bookings_columns.include?("confirmation_email_sent_at")
  ensure
    @migration.up if bookings_columns.include?("confirmation_email_sent_at")
    Booking.reset_column_information
  end

  private

  def bookings_columns
    ActiveRecord::Base.connection.columns(:bookings).map(&:name)
  end
end
