# frozen_string_literal: true

require "test_helper"

class Bookings::ErrorsTest < ActiveSupport::TestCase
  test "booking_conflict_exception? returns true for known booking slot constraint" do
    client = Client.create!(name: "Salon Error Known", slug: "salon-error-known")
    enseigne = client.enseignes.create!(name: "Enseigne Known")
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2000)

    start_time = Time.current.change(sec: 0)

    Booking.create!(
      client: client,
      enseigne: enseigne,
      service: service,
      booking_start_time: start_time,
      booking_end_time: start_time + 30.minutes,
      booking_status: :confirmed,
      customer_first_name: "Ada",
      customer_last_name: "Lovelace",
      customer_email: "ada@example.com",
      confirmation_token: SecureRandom.uuid
    )

    error = assert_raises ActiveRecord::StatementInvalid do
      Booking.insert_all!([
        {
          client_id: client.id,
          enseigne_id: enseigne.id,
          service_id: service.id,
          booking_start_time: start_time + 15.minutes,
          booking_end_time: start_time + 45.minutes,
          booking_status: "confirmed",
          customer_first_name: "Grace",
          customer_last_name: "Hopper",
          customer_email: "grace@example.com",
          confirmation_token: SecureRandom.uuid,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    end

    assert Bookings::Errors.booking_conflict_exception?(error)
  end

  test "booking_conflict_exception? returns false for unknown constraint" do
    timestamp = Time.current
    slug = "bookings-errors-unknown-constraint"

    Client.insert_all!([
      { name: "Salon A", slug: slug, created_at: timestamp, updated_at: timestamp }
    ])

    error = assert_raises ActiveRecord::RecordNotUnique do
      Client.insert_all!([
        { name: "Salon B", slug: slug, created_at: timestamp, updated_at: timestamp }
      ])
    end

    assert_not Bookings::Errors.booking_conflict_exception?(error)
  end
end
