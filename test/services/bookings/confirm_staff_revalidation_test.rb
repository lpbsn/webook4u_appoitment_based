require "test_helper"

class Bookings::ConfirmStaffRevalidationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Client confirm revalidation", slug: "client-confirm-revalidation")
    @enseigne = @client.enseignes.create!(name: "Enseigne confirm revalidation")
    @service = @enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)
    @staff = @enseigne.staffs.create!(name: "Staff A", active: true)
    @other_staff = @enseigne.staffs.create!(name: "Staff B", active: true)
  end

  test "returns confirmable for pending non expired booking with assigned staff and no blocking booking" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = build_pending_booking(staff: @staff, starts_at: Time.zone.local(2026, 3, 16, 10, 0, 0))

      result = Bookings::ConfirmStaffRevalidation.new(booking: booking).call

      assert result.confirmable?
      assert_nil result.error_code
      assert_equal @staff, result.staff
    end
  end

  test "returns not pending when booking is already confirmed" do
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      staff: @staff,
      booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
      booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
      booking_status: :confirmed,
      customer_first_name: "Ada",
      customer_last_name: "Lovelace",
      customer_email: "ada@example.com"
    )

    result = Bookings::ConfirmStaffRevalidation.new(booking: booking).call

    assert_not result.confirmable?
    assert_equal Bookings::Errors::NOT_PENDING, result.error_code
  end

  test "returns session expired when pending booking is expired" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = build_pending_booking(
        staff: @staff,
        starts_at: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_expires_at: 1.minute.ago
      )

      result = Bookings::ConfirmStaffRevalidation.new(booking: booking).call

      assert_not result.confirmable?
      assert_equal Bookings::Errors::SESSION_EXPIRED, result.error_code
    end
  end

  test "returns slot unavailable when pending booking has no assigned staff" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = build_pending_booking(staff: nil, starts_at: Time.zone.local(2026, 3, 16, 11, 0, 0))

      result = Bookings::ConfirmStaffRevalidation.new(booking: booking).call

      assert_not result.confirmable?
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
    end
  end

  test "returns slot unavailable when overlapping blocking booking exists on assigned staff" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      starts_at = Time.zone.local(2026, 3, 16, 11, 30, 0)
      booking = build_pending_booking(staff: @staff, starts_at: starts_at)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: starts_at,
        booking_end_time: starts_at + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Other",
        customer_last_name: "User",
        customer_email: "other@example.com"
      )

      result = Bookings::ConfirmStaffRevalidation.new(booking: booking).call

      assert_not result.confirmable?
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
    end
  end

  test "ignores overlapping booking on another staff" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      starts_at = Time.zone.local(2026, 3, 16, 12, 0, 0)
      booking = build_pending_booking(staff: @staff, starts_at: starts_at)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @other_staff,
        booking_start_time: starts_at,
        booking_end_time: starts_at + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Other",
        customer_last_name: "User",
        customer_email: "other@example.com"
      )

      result = Bookings::ConfirmStaffRevalidation.new(booking: booking).call

      assert result.confirmable?
      assert_nil result.error_code
    end
  end

  test "does not re-evaluate active or capability for already assigned staff" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      @staff.update!(active: false)
      booking = build_pending_booking(staff: @staff, starts_at: Time.zone.local(2026, 3, 16, 12, 30, 0))

      result = Bookings::ConfirmStaffRevalidation.new(booking: booking).call

      assert result.confirmable?
      assert_nil result.error_code
    end
  end

  test "does not use Resource.for_enseigne" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = build_pending_booking(staff: @staff, starts_at: Time.zone.local(2026, 3, 16, 13, 0, 0))

      resource_singleton = class << Bookings::Resource; self; end
      resource_singleton.alias_method :for_enseigne_without_confirm_staff_revalidation_test, :for_enseigne
      resource_singleton.define_method(:for_enseigne) do |*_args, **_kwargs|
        raise "Resource.for_enseigne should not be called by ConfirmStaffRevalidation"
      end

      begin
        result = Bookings::ConfirmStaffRevalidation.new(booking: booking).call
        assert result.confirmable?
      ensure
        resource_singleton.alias_method :for_enseigne, :for_enseigne_without_confirm_staff_revalidation_test
        resource_singleton.remove_method :for_enseigne_without_confirm_staff_revalidation_test
      end
    end
  end

  private

  def build_pending_booking(staff:, starts_at:, booking_expires_at: BookingRules.pending_expires_at)
    @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      staff: staff,
      booking_start_time: starts_at,
      booking_end_time: starts_at + 30.minutes,
      booking_status: :pending,
      booking_expires_at: booking_expires_at
    )
  end
end
