require "test_helper"
require Rails.root.join("db/migrate/20260402133000_enforce_bookings_cross_table_consistency")

class EnforceBookingsCrossTableConsistencyMigrationTest < SchemaMutationMigrationTestCase
  def setup
    @migration = EnforceBookingsCrossTableConsistency.new
  end

  test "up installs trigger function enforcing service, staff and client consistency" do
    @migration.up

    function_sql = trigger_function_sql
    assert_includes function_sql, "bookings.enseigne_id must match services.enseigne_id"
    assert_includes function_sql, "bookings.enseigne_id must match staffs.enseigne_id"
    assert_includes function_sql, "bookings.client_id must match enseignes.client_id"
  ensure
    @migration.up
  end

  test "down restores trigger function without staff consistency enforcement" do
    @migration.down

    function_sql = trigger_function_sql
    assert_includes function_sql, "bookings.enseigne_id must match services.enseigne_id"
    assert_includes function_sql, "bookings.client_id must match enseignes.client_id"
    assert_not_includes function_sql, "bookings.enseigne_id must match staffs.enseigne_id"
  ensure
    @migration.up
  end

  test "up fails explicitly when an existing booking references a staff from another enseigne" do
    @migration.down

    client = Client.create!(name: "Cross-table migration client", slug: "cross-table-migration-client")
    primary_enseigne = client.enseignes.create!(name: "Primary enseigne")
    secondary_enseigne = client.enseignes.create!(name: "Secondary enseigne")
    service = primary_enseigne.services.create!(name: "Cross-table service", duration_minutes: 30, price_cents: 2500)
    staff_from_other_enseigne = secondary_enseigne.staffs.create!(name: "Mismatch staff")

    now = Time.current
    Booking.insert_all!([
      {
        client_id: client.id,
        enseigne_id: primary_enseigne.id,
        service_id: service.id,
        staff_id: staff_from_other_enseigne.id,
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

    error = assert_raises(RuntimeError) { @migration.up }
    assert_includes error.message, "Cannot enforce bookings cross-table consistency trigger"
    assert_includes error.message, "staff mismatch row(s)"
    assert_includes error.message, inconsistent_booking.id.to_s
  ensure
    Booking.where(id: inconsistent_booking&.id).delete_all
    @migration.up
  end

  private

  def trigger_function_sql
    result = ActiveRecord::Base.connection.execute(<<~SQL.squish).to_a
      SELECT pg_get_functiondef('enforce_bookings_client_consistency'::regproc) AS definition
    SQL

    result.first.fetch("definition")
  end
end
