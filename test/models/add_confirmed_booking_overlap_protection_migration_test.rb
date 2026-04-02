require "test_helper"
require Rails.root.join("db/migrate/20260401120000_add_confirmed_booking_overlap_protection")

class AddConfirmedBookingOverlapProtectionMigrationTest < SchemaMutationMigrationTestCase
  test "migration fails explicitly when overlapping confirmed bookings already exist" do
    migration = AddConfirmedBookingOverlapProtection.new
    migration.down

    client = Client.create!(name: "Client overlap", slug: "client-overlap-migration")
    enseigne = client.enseignes.create!(name: "Enseigne overlap", full_address: "1 rue overlap")
    service = enseigne.services.create!(name: "Service overlap", duration_minutes: 30, price_cents: 1200)
    first_staff = enseigne.staffs.create!(name: "Staff overlap migration 1", active: true)
    second_staff = enseigne.staffs.create!(name: "Staff overlap migration 2", active: true)

    now = Time.current

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

    error = assert_raises(RuntimeError) { migration.up }
    assert_includes error.message, "Cannot add confirmed bookings overlap protection"
    assert_includes error.message, "#{left.id}/#{right.id}"
  ensure
    Booking.where(id: [ left&.id, right&.id ].compact).delete_all
    migration.up
  end
end
