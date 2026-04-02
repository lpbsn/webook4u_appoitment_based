require "test_helper"
require Rails.root.join("db/migrate/20260325130000_add_bookings_client_consistency_trigger")
require Rails.root.join("db/migrate/20260402114000_update_bookings_service_consistency_to_enseigne")
require Rails.root.join("db/migrate/20260402133000_enforce_bookings_cross_table_consistency")

class AddBookingsClientConsistencyTriggerMigrationTest < SchemaMutationMigrationTestCase
  test "migration fails explicitly when inconsistent bookings already exist" do
    migration = AddBookingsClientConsistencyTrigger.new
    migration.down

    client_a = Client.create!(name: "Client A", slug: "migration-client-a")
    client_b = Client.create!(name: "Client B", slug: "migration-client-b")

    enseigne_a = client_a.enseignes.create!(name: "Enseigne A", full_address: "1 rue A")
    enseigne_b = client_b.enseignes.create!(name: "Enseigne B", full_address: "2 rue B")
    service_b = enseigne_b.services.create!(name: "Service B", duration_minutes: 30, price_cents: 1200)
    service_b.update_column(:client_id, client_b.id)

    now = Time.current
    Booking.insert_all!([
      {
        client_id: client_a.id,
        enseigne_id: enseigne_a.id,
        service_id: service_b.id,
        booking_start_time: now,
        booking_end_time: now + 30.minutes,
        booking_status: "pending",
        booking_expires_at: now + 5.minutes,
        pending_access_token: SecureRandom.urlsafe_base64(24),
        created_at: now,
        updated_at: now
      }
    ])

    inconsistent_booking = Booking.order(:id).last

    error = assert_raises(RuntimeError) { migration.up }
    assert_includes error.message, "Cannot add bookings client consistency trigger"
    assert_includes error.message, "inconsistent row(s)"
    assert_includes error.message, inconsistent_booking.id.to_s

    inconsistent_booking.reload
    assert_equal client_a.id, inconsistent_booking.client_id
    assert_equal service_b.id, inconsistent_booking.service_id
  ensure
    Booking.where(id: inconsistent_booking&.id).delete_all
    migration.up
    UpdateBookingsServiceConsistencyToEnseigne.new.up
    EnforceBookingsCrossTableConsistency.new.up
  end
end
