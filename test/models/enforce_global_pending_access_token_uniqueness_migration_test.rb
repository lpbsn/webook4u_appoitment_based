require "test_helper"
require Rails.root.join("db/migrate/20260402060100_enforce_global_pending_access_token_uniqueness")

class EnforceGlobalPendingAccessTokenUniquenessMigrationTest < SchemaMutationMigrationTestCase
  test "migration fails explicitly when a booking token collides with expired booking links" do
    migration = EnforceGlobalPendingAccessTokenUniqueness.new
    migration.down

    client = Client.create!(name: "Collision client", slug: "collision-client")
    enseigne = client.enseignes.create!(name: "Collision enseigne", full_address: "1 rue collision")
    service = enseigne.services.create!(name: "Collision service", duration_minutes: 30, price_cents: 1500)

    reused_token = "global-collision-token"
    now = Time.current

    booking = client.bookings.create!(
      enseigne: enseigne,
      service: service,
      booking_start_time: now,
      booking_end_time: now + 30.minutes,
      booking_status: :pending,
      booking_expires_at: now + 5.minutes,
      pending_access_token: reused_token
    )

    ExpiredBookingLink.insert_all!([
      {
        client_id: client.id,
        pending_access_token: reused_token,
        booking_date: now.to_date,
        expired_at: now - 1.hour,
        created_at: now,
        updated_at: now
      }
    ])
    expired_link = ExpiredBookingLink.order(:id).last

    error = assert_raises(RuntimeError) { migration.up }
    assert_includes error.message, "Cannot enforce global pending_access_token uniqueness"
    assert_includes error.message, "colliding with expired_booking_links"
    assert_includes error.message, booking.id.to_s

    booking.reload
    expired_link.reload
    assert_equal reused_token, booking.pending_access_token
    assert_equal reused_token, expired_link.pending_access_token
  ensure
    Booking.where(id: booking&.id).delete_all
    ExpiredBookingLink.where(id: expired_link&.id).delete_all
    migration.up
  end
end
