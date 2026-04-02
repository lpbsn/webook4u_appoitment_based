# frozen_string_literal: true

require "test_helper"

class Bookings::SlotDecisionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Salon Slot Decision", slug: "salon-slot-decision")
    @enseigne = @client.enseignes.create!(name: "Enseigne A", full_address: "1 rue A")
    @other_enseigne = @client.enseignes.create!(name: "Enseigne B", full_address: "2 rue B")
    @service = @enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)
    @staff = @enseigne.staffs.create!(name: "Staff slot decision", active: true)
    create_weekday_opening_hours_for_enseigne(@enseigne)
  end

  test "returns invalid slot when booking_start_time is nil" do
    result = build_decision(booking_start_time: nil).call

    assert_not result.bookable?
    assert_equal Bookings::Errors::INVALID_SLOT, result.error_code
    assert_equal Bookings::Errors.message_for(Bookings::Errors::INVALID_SLOT), result.error_message
    assert_nil result.booking_end_time
    assert_not result.matches_schedule_grid?
  end

  test "marks a slot as outside the schedule grid without making it unavailable when only the cadence is invalid" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      result = build_decision(
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 15, 0)
      ).call

      assert result.bookable?
      assert_nil result.error_code
      assert_not result.matches_schedule_grid?
    end
  end

  test "returns slot unavailable when an overlapping confirmed booking exists, even if the interval is not schedule-grid aligned" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      @client.bookings.create!(
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

      result = build_decision(
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 15, 0)
      ).call

      assert_not result.bookable?
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SLOT_UNAVAILABLE), result.error_message
      assert_not result.matches_schedule_grid?
    end
  end

  test "returns slot unavailable while keeping schedule-grid alignment true for an aligned blocked slot" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      result = build_decision(
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0)
      ).call

      assert_not result.bookable?
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SLOT_UNAVAILABLE), result.error_message
      assert result.matches_schedule_grid?
    end
  end

  test "returns slot unavailable before schedule-grid mismatch when a non aligned slot is already blocked" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      blocked_start = Time.zone.local(2026, 3, 16, 10, 15, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: blocked_start,
        booking_end_time: blocked_start + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Ada",
        customer_last_name: "Lovelace",
        customer_email: "ada@example.com"
      )

      result = build_decision(booking_start_time: blocked_start).call

      assert_not result.bookable?
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
      assert_not result.matches_schedule_grid?
    end
  end

  test "returns bookable when no blocking booking exists" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 11, 0, 0)
      result = build_decision(booking_start_time: slot).call

      assert result.bookable?
      assert_nil result.error_code
      assert_equal slot + 30.minutes, result.booking_end_time
      assert_equal @enseigne.id, result.resource.identifier
      assert result.matches_schedule_grid?
    end
  end

  test "returns bookable when slot starts at end of another booking" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      first_start = Time.zone.local(2026, 3, 16, 10, 0, 0)
      first_end = first_start + 30.minutes

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: first_start,
        booking_end_time: first_end,
        booking_status: :confirmed,
        customer_first_name: "Ada",
        customer_last_name: "Lovelace",
        customer_email: "ada@example.com"
      )

      result = build_decision(booking_start_time: first_end).call

      assert result.bookable?
      assert result.matches_schedule_grid?
    end
  end

  test "returns bookable when blocking booking belongs to another enseigne" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 12, 0, 0)
      other_service = @other_enseigne.services.create!(name: "Coloration", duration_minutes: 30, price_cents: 3000)
      other_staff = @other_enseigne.staffs.create!(name: "Staff slot decision other", active: true)

      @client.bookings.create!(
        enseigne: @other_enseigne,
        service: other_service,
        staff: other_staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Ada",
        customer_last_name: "Lovelace",
        customer_email: "ada@example.com"
      )

      result = build_decision(booking_start_time: slot).call

      assert result.bookable?
      assert result.matches_schedule_grid?
    end
  end

  test "confirmation excludes the booking itself from blocking checks" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 13, 0, 0)
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      result = build_decision(
        booking_start_time: slot,
        exclude_booking_id: booking.id
      ).call

      assert result.bookable?
      assert result.matches_schedule_grid?
    end
  end

  test "marks slot outside schedule grid when minimum notice has moved past it, without treating that alone as unavailability" do
    travel_to Time.zone.local(2026, 3, 16, 14, 10, 0) do
      result = build_decision(
        booking_start_time: Time.zone.local(2026, 3, 16, 14, 30, 0)
      ).call

      assert result.bookable?
      assert_nil result.error_code
      assert_not result.matches_schedule_grid?
      assert_equal Time.zone.local(2026, 3, 16, 15, 0, 0), result.booking_end_time
    end
  end

  test "does not consult AvailableSlots to evaluate a slot" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      available_slots_singleton = class << Bookings::AvailableSlots; self; end
      available_slots_singleton.alias_method :new_without_slot_decision_test, :new
      available_slots_singleton.define_method(:new) do |*_args|
        raise "AvailableSlots should not be called by SlotDecision"
      end

      begin
        result = build_decision(
          booking_start_time: Time.zone.local(2026, 3, 16, 10, 15, 0)
        ).call

        assert result.bookable?
        assert_not result.matches_schedule_grid?
      ensure
        available_slots_singleton.alias_method :new, :new_without_slot_decision_test
        available_slots_singleton.remove_method :new_without_slot_decision_test
      end
    end
  end

  private

  def build_decision(booking_start_time:, exclude_booking_id: nil)
    Bookings::SlotDecision.new(
      client: @client,
      enseigne: @enseigne,
      service: @service,
      booking_start_time: booking_start_time,
      exclude_booking_id: exclude_booking_id
    )
  end
end
