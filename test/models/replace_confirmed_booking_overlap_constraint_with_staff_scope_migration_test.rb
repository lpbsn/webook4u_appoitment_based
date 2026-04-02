require "test_helper"
require Rails.root.join("db/migrate/20260402153000_replace_confirmed_booking_overlap_constraint_with_staff_scope")

class ReplaceConfirmedBookingOverlapConstraintWithStaffScopeMigrationTest < SchemaMutationMigrationTestCase
  OLD_CONSTRAINT_NAME = "bookings_confirmed_no_overlapping_intervals_per_enseigne"
  NEW_CONSTRAINT_NAME = "bookings_confirmed_no_overlapping_intervals_per_staff"

  def setup
    @migration = ReplaceConfirmedBookingOverlapConstraintWithStaffScope.new
  end

  test "up replaces enseigne-scoped overlap constraint with staff-scoped overlap constraint" do
    @migration.down

    assert constraint_exists?(OLD_CONSTRAINT_NAME)
    assert_not constraint_exists?(NEW_CONSTRAINT_NAME)

    @migration.up

    assert_not constraint_exists?(OLD_CONSTRAINT_NAME)
    assert constraint_exists?(NEW_CONSTRAINT_NAME)
  ensure
    @migration.up
  end

  test "down fails explicitly when overlapping confirmed bookings exist in same enseigne on different staffs" do
    @migration.up

    client = Client.create!(name: "Client rollback overlap", slug: "client-rollback-overlap")
    enseigne = client.enseignes.create!(name: "Enseigne rollback overlap")
    service = enseigne.services.create!(name: "Service rollback overlap", duration_minutes: 30, price_cents: 1200)
    first_staff = enseigne.staffs.create!(name: "Staff rollback 1", active: true)
    second_staff = enseigne.staffs.create!(name: "Staff rollback 2", active: true)

    now = Time.current.change(sec: 0)

    left = client.bookings.create!(
      enseigne: enseigne,
      service: service,
      staff: first_staff,
      booking_start_time: now,
      booking_end_time: now + 30.minutes,
      booking_status: :confirmed,
      customer_first_name: "Left",
      customer_last_name: "Booking",
      customer_email: "left@example.com"
    )

    right = client.bookings.create!(
      enseigne: enseigne,
      service: service,
      staff: second_staff,
      booking_start_time: now + 15.minutes,
      booking_end_time: now + 45.minutes,
      booking_status: :confirmed,
      customer_first_name: "Right",
      customer_last_name: "Booking",
      customer_email: "right@example.com"
    )

    error = assert_raises(RuntimeError) { @migration.down }
    assert_includes error.message, "Cannot restore enseigne-scoped confirmed overlap protection"
    assert_includes error.message, "#{left.id}/#{right.id}"
  ensure
    Booking.where(id: [ left&.id, right&.id ].compact).delete_all
    @migration.up
  end

  private

  def constraint_exists?(name)
    ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = #{ActiveRecord::Base.connection.quote(name)}
      )
    SQL
  end
end
