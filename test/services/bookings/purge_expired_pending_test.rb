require "test_helper"

class Bookings::PurgeExpiredPendingTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Client purge", slug: "client-purge")
    @enseigne = @client.enseignes.create!(name: "Enseigne purge")
    @service = @enseigne.services.create!(name: "Service purge", duration_minutes: 30, price_cents: 1500)
  end

  test "deletes only pending bookings expired strictly before cutoff" do
    travel_to Time.zone.local(2026, 4, 1, 10, 0, 0) do
      expired_pending = create_booking(
        status: :pending,
        starts_at: Time.zone.local(2026, 4, 2, 10, 0, 0),
        expires_at: 1.minute.ago
      )
      boundary_pending = create_booking(
        status: :pending,
        starts_at: Time.zone.local(2026, 4, 2, 10, 30, 0),
        expires_at: Time.zone.now
      )
      active_pending = create_booking(
        status: :pending,
        starts_at: Time.zone.local(2026, 4, 2, 11, 0, 0),
        expires_at: 1.minute.from_now
      )
      confirmed = create_booking(
        status: :confirmed,
        starts_at: Time.zone.local(2026, 4, 2, 11, 30, 0)
      )
      failed = create_booking(
        status: :failed,
        starts_at: Time.zone.local(2026, 4, 2, 12, 0, 0)
      )

      result = Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now)

      assert_equal 1, result.deleted_count
      assert_equal 1, result.upsert_attempt_count
      assert_equal 1, result.batch_count
      assert_equal Time.zone.now, result.cutoff
      assert_not Booking.exists?(expired_pending.id)
      assert Booking.exists?(boundary_pending.id)
      assert Booking.exists?(active_pending.id)
      assert Booking.exists?(confirmed.id)
      assert Booking.exists?(failed.id)

      tombstone = ExpiredBookingLink.find_by!(client_id: @client.id, pending_access_token: expired_pending.pending_access_token)
      assert_equal @enseigne.id, tombstone.enseigne_id
      assert_equal @service.id, tombstone.service_id
      assert_equal Date.new(2026, 4, 2), tombstone.booking_date
      assert_equal expired_pending.booking_expires_at.to_i, tombstone.expired_at.to_i
    end
  end

  test "is idempotent when called twice with the same cutoff" do
    travel_to Time.zone.local(2026, 4, 1, 10, 0, 0) do
      expired_pending = create_booking(
        status: :pending,
        starts_at: Time.zone.local(2026, 4, 2, 13, 0, 0),
        expires_at: 2.minutes.ago
      )
      cutoff = Time.zone.now

      first_result = Bookings::PurgeExpiredPending.call(cutoff: cutoff)
      second_result = Bookings::PurgeExpiredPending.call(cutoff: cutoff)

      assert_equal 1, first_result.deleted_count
      assert_equal 1, first_result.upsert_attempt_count
      assert_equal 0, second_result.deleted_count
      assert_equal 0, second_result.upsert_attempt_count
      assert_not Booking.exists?(expired_pending.id)
      assert_equal 1, ExpiredBookingLink.where(client_id: @client.id, pending_access_token: expired_pending.pending_access_token).count
    end
  end

  test "persists expired pending link context for deleted bookings" do
    travel_to Time.zone.local(2026, 4, 1, 10, 0, 0) do
      expired_pending = create_booking(
        status: :pending,
        starts_at: Time.zone.local(2026, 4, 2, 9, 0, 0),
        expires_at: 5.minutes.ago
      )

      Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now)

      expired_link = ExpiredBookingLink.find_by!(client_id: @client.id, pending_access_token: expired_pending.pending_access_token)

      assert_equal @enseigne.id, expired_link.enseigne_id
      assert_equal @service.id, expired_link.service_id
      assert_equal Date.new(2026, 4, 2), expired_link.booking_date
    end
  end

  test "processes expired pending bookings in batches" do
    travel_to Time.zone.local(2026, 4, 1, 10, 0, 0) do
      3.times do |index|
        create_booking(
          status: :pending,
          starts_at: Time.zone.local(2026, 4, 2, 9 + index, 0, 0),
          expires_at: 5.minutes.ago
        )
      end

      result = Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now, batch_size: 2)

      assert_equal 3, result.deleted_count
      assert_equal 3, result.upsert_attempt_count
      assert_equal 2, result.batch_count
      assert_equal 3, ExpiredBookingLink.count
    end
  end

  private

  def create_booking(status:, starts_at:, expires_at: nil)
    attrs = {
      client: @client,
      enseigne: @enseigne,
      service: @service,
      booking_start_time: starts_at,
      booking_end_time: starts_at + 30.minutes,
      booking_status: status
    }

    case status
    when :pending
      attrs[:booking_expires_at] = expires_at
    when :confirmed
      attrs[:customer_first_name] = "Jean"
      attrs[:customer_last_name] = "Dupont"
      attrs[:customer_email] = "jean@example.com"
    end

    @client.bookings.create!(attrs)
  end
end
