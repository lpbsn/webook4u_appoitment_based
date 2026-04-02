require "test_helper"
require Rails.root.join("db/migrate/20260402160000_add_confirmed_requires_staff_to_bookings")

class AddConfirmedRequiresStaffToBookingsMigrationTest < SchemaMutationMigrationTestCase
  CONSTRAINT_NAME = "bookings_confirmed_requires_staff_id"

  def setup
    @migration = AddConfirmedRequiresStaffToBookings.new
  end

  test "up adds confirmed requires staff check constraint and down removes it" do
    @migration.down

    assert_not constraint_exists?(CONSTRAINT_NAME)

    @migration.up

    assert constraint_exists?(CONSTRAINT_NAME)

    @migration.down

    assert_not constraint_exists?(CONSTRAINT_NAME)
  ensure
    @migration.up
  end

  test "up fails explicitly when confirmed bookings without staff exist" do
    @migration.down

    client = Client.create!(name: "Client confirmed without staff migration", slug: "client-confirmed-without-staff-migration")
    enseigne = client.enseignes.create!(name: "Enseigne confirmed without staff migration")
    service = enseigne.services.create!(name: "Service confirmed without staff migration", duration_minutes: 30, price_cents: 2000)
    now = Time.current.change(sec: 0)

    Booking.insert_all!([
      {
        client_id: client.id,
        enseigne_id: enseigne.id,
        service_id: service.id,
        booking_start_time: now,
        booking_end_time: now + 30.minutes,
        booking_status: "confirmed",
        customer_first_name: "Jean",
        customer_last_name: "Dupont",
        customer_email: "jean.dupont@example.com",
        confirmation_token: SecureRandom.uuid,
        created_at: now,
        updated_at: now
      }
    ])

    error = assert_raises(RuntimeError) { @migration.up }
    assert_includes error.message, "Cannot enforce confirmed staff requirement"
    assert_not constraint_exists?(CONSTRAINT_NAME)
  ensure
    Booking.where(client_id: client&.id).delete_all
    Service.where(id: service&.id).delete_all
    Enseigne.where(id: enseigne&.id).delete_all
    Client.where(id: client&.id).delete_all
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
