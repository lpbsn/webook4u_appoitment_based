require "test_helper"

class Bookings::CreatePendingStaffRevalidationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Client revalidation", slug: "client-revalidation")
    @enseigne = @client.enseignes.create!(name: "Enseigne revalidation")
    @service = @enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)
    @staff = @enseigne.staffs.create!(name: "Staff A", active: true)

    StaffServiceCapability.create!(staff: @staff, service: @service)
    create_weekday_opening_hours_for_enseigne(@enseigne)
    create_weekday_staff_availabilities_for(@staff)
  end

  test "returns bookable and creatable for a valid free slot on staff candidate" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)
      result = build_revalidation(booking_start_time: slot).call

      assert result.bookable?
      assert result.creatable?
      assert_nil result.error_code
      assert_equal slot + 30.minutes, result.booking_end_time
      assert_equal @staff, result.staff
    end
  end

  test "returns invalid slot when booking_start_time is nil" do
    result = build_revalidation(booking_start_time: nil).call

    assert_not result.bookable?
    assert_not result.creatable?
    assert_equal Bookings::Errors::INVALID_SLOT, result.error_code
    assert_nil result.booking_end_time
  end

  test "returns slot unavailable when candidate staff is not eligible" do
    @staff.update!(active: false)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      result = build_revalidation(
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0)
      ).call

      assert_not result.bookable?
      assert_not result.creatable?
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
    end
  end

  test "returns slot unavailable when overlapping blocking booking exists on same staff" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 11, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Ada",
        customer_last_name: "Lovelace",
        customer_email: "ada@example.com"
      )

      result = build_revalidation(booking_start_time: slot).call

      assert_not result.bookable?
      assert_not result.creatable?
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
    end
  end

  test "expired pending booking does not block revalidation on staff" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 11, 30, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )

      result = build_revalidation(booking_start_time: slot).call

      assert result.bookable?
      assert result.creatable?
    end
  end

  private

  def build_revalidation(booking_start_time:)
    Bookings::CreatePendingStaffRevalidation.new(
      client: @client,
      enseigne: @enseigne,
      service: @service,
      staff: @staff,
      booking_start_time: booking_start_time
    )
  end
end
