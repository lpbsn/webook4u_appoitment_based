require "test_helper"
require Rails.root.join("db/migrate/20260325123000_add_status_based_required_field_checks_to_bookings")

class AddStatusBasedRequiredFieldChecksToBookingsMigrationTest < SchemaMutationMigrationTestCase
  test "fails when confirmed booking has missing customer fields and does not alter data" do
    drop_confirmed_required_constraints!

    client = Client.create!(name: "Client migration", slug: "client-migration")
    enseigne = client.enseignes.create!(name: "Enseigne migration", full_address: "1 rue migration")
    service = enseigne.services.create!(name: "Service migration", duration_minutes: 30, price_cents: 1000)

    now = Time.current
    Booking.insert_all!([
      {
        client_id: client.id,
        enseigne_id: enseigne.id,
        service_id: service.id,
        booking_start_time: now,
        booking_end_time: now + 30.minutes,
        booking_status: "confirmed",
        customer_first_name: nil,
        customer_last_name: nil,
        customer_email: nil,
        confirmation_token: nil,
        created_at: now,
        updated_at: now
      }
    ])

    booking = Booking.order(:id).last
    migration = AddStatusBasedRequiredFieldChecksToBookings.new

    error = assert_raises(RuntimeError) do
      migration.send(:sanitize_non_conforming_rows!)
    end

    assert_includes error.message, "found 1 incomplete confirmed booking(s)"
    assert_includes error.message, booking.id.to_s
    assert_includes error.message, "No synthetic customer data was written"

    booking.reload
    assert_nil booking.customer_first_name
    assert_nil booking.customer_last_name
    assert_nil booking.customer_email
  ensure
    Booking.where(id: booking&.id).delete_all
    add_confirmed_required_constraints!
  end

  private

  def drop_confirmed_required_constraints!
    execute_sql "ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_confirmed_requires_customer_first_name"
    execute_sql "ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_confirmed_requires_customer_last_name"
    execute_sql "ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_confirmed_requires_customer_email"
    execute_sql "ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_confirmed_requires_confirmation_token"
  end

  def add_confirmed_required_constraints!
    execute_sql <<~SQL.squish
      ALTER TABLE bookings
      ADD CONSTRAINT bookings_confirmed_requires_customer_first_name
      CHECK (booking_status <> 'confirmed' OR NULLIF(BTRIM(customer_first_name), '') IS NOT NULL)
    SQL
    execute_sql <<~SQL.squish
      ALTER TABLE bookings
      ADD CONSTRAINT bookings_confirmed_requires_customer_last_name
      CHECK (booking_status <> 'confirmed' OR NULLIF(BTRIM(customer_last_name), '') IS NOT NULL)
    SQL
    execute_sql <<~SQL.squish
      ALTER TABLE bookings
      ADD CONSTRAINT bookings_confirmed_requires_customer_email
      CHECK (booking_status <> 'confirmed' OR NULLIF(BTRIM(customer_email), '') IS NOT NULL)
    SQL
    execute_sql <<~SQL.squish
      ALTER TABLE bookings
      ADD CONSTRAINT bookings_confirmed_requires_confirmation_token
      CHECK (booking_status <> 'confirmed' OR NULLIF(BTRIM(confirmation_token), '') IS NOT NULL)
    SQL
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?("already exists")
  end

  def execute_sql(sql)
    ActiveRecord::Base.connection.execute(sql)
  end
end
