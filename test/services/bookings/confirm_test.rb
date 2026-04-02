require "test_helper"

class Bookings::ConfirmTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(
      name: "Le Salon Des gâté",
      slug: "salon-des-gate"
    )

    @enseigne = @client.enseignes.create!(
      name: "Enseigne principale"
    )
    @other_enseigne = @client.enseignes.create!(
      name: "Enseigne secondaire"
    )

    @service = @enseigne.services.create!(
      name: "Coupe homme",
      duration_minutes: 30,
      price_cents: 2500
    )
  end

  test "confirms a valid pending booking" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      result = Bookings::Confirm.new(
        booking: booking,
        booking_params: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      ).call

      assert result.success?
      assert_equal booking, result.booking
      assert_nil result.error_code
      assert_nil result.error_message

      booking.reload
      assert_equal "confirmed", booking.booking_status
      assert_equal "Léonard", booking.customer_first_name
      assert_equal "Boisson", booking.customer_last_name
      assert_equal "leo@example.com", booking.customer_email
    end
  end

  test "fails when booking is no longer pending" do
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
      booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
      booking_status: :confirmed,
      customer_first_name: "Léonard",
      customer_last_name: "Boisson",
      customer_email: "leo@example.com"
    )

    result = Bookings::Confirm.new(
      booking: booking,
      booking_params: {
        customer_first_name: "Test",
        customer_last_name: "User",
        customer_email: "test@example.com"
      }
    ).call

    assert_not result.success?
    assert_equal booking, result.booking
    assert_equal Bookings::Errors::NOT_PENDING, result.error_code
    assert_equal "Cette réservation ne peut plus être confirmée. Veuillez recommencer votre sélection.", result.error_message
  end

  test "fails when booking is already failed" do
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      booking_start_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
      booking_end_time: Time.zone.local(2026, 3, 16, 12, 0, 0),
      booking_status: :failed
    )

    result = Bookings::Confirm.new(
      booking: booking,
      booking_params: {
        customer_first_name: "Test",
        customer_last_name: "User",
        customer_email: "test@example.com"
      }
    ).call

    assert_not result.success?
    assert_equal booking, result.booking
    assert_equal Bookings::Errors::NOT_PENDING, result.error_code

    booking.reload
    assert_equal "failed", booking.booking_status
  end

  test "fails when pending booking is expired" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 12, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 12, 30, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )

      result = Bookings::Confirm.new(
        booking: booking,
        booking_params: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      ).call

      assert_not result.success?
      assert_equal Bookings::Errors::SESSION_EXPIRED, result.error_code
      assert_equal "Votre session a expiré. Veuillez renouveler votre réservation.", result.error_message

      booking.reload
      assert_equal "pending", booking.booking_status
    end
  end

  test "fails when another booking already blocks the same slot" do
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

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Other",
        customer_last_name: "User",
        customer_email: "other@example.com"
      )

      result = Bookings::Confirm.new(
        booking: booking,
        booking_params: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      ).call

      assert_not result.success?
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
      assert_equal "Le créneau sélectionné n'est plus disponible.", result.error_message

      booking.reload
      assert_equal "pending", booking.booking_status
    end
  end

  test "confirmation does not depend on schedule-grid alignment remaining true at confirmation time" do
    travel_to Time.zone.local(2026, 3, 16, 10, 4, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.from_now
      )

      result = Bookings::Confirm.new(
        booking: booking,
        booking_params: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      ).call

      assert result.success?
      assert_nil result.error_code

      booking.reload
      assert_equal "confirmed", booking.booking_status
    end
  end

  test "confirmation delegates slot revalidation to SlotDecision with exclude_booking_id" do
    travel_to Time.zone.local(2026, 3, 16, 10, 4, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.from_now
      )
      calls = []

      slot_decision_singleton = class << Bookings::SlotDecision; self; end
      slot_decision_singleton.alias_method :new_without_confirm_orchestration_test, :new
      slot_decision_singleton.define_method(:new) do |**kwargs|
        calls << kwargs.slice(:client, :enseigne, :service, :booking_start_time, :exclude_booking_id, :resource)
        new_without_confirm_orchestration_test(**kwargs)
      end

      begin
        result = Bookings::Confirm.new(
          booking: booking,
          booking_params: {
            customer_first_name: "Léonard",
            customer_last_name: "Boisson",
            customer_email: "leo@example.com"
          }
        ).call

        assert result.success?
        assert_equal 1, calls.size

        call = calls.first
        assert_equal booking.client, call[:client]
        assert_equal booking.enseigne, call[:enseigne]
        assert_equal booking.service, call[:service]
        assert_equal booking.booking_start_time, call[:booking_start_time]
        assert_equal booking.id, call[:exclude_booking_id]
        assert_equal booking.enseigne_id, call[:resource].identifier
      ensure
        slot_decision_singleton.alias_method :new, :new_without_confirm_orchestration_test
        slot_decision_singleton.remove_method :new_without_confirm_orchestration_test
      end
    end
  end

  test "confirmation does not consult AvailableSlots during transactional revalidation" do
    travel_to Time.zone.local(2026, 3, 16, 10, 4, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.from_now
      )

      available_slots_singleton = class << Bookings::AvailableSlots; self; end
      available_slots_singleton.alias_method :new_without_confirm_available_slots_test, :new
      available_slots_singleton.define_method(:new) do |*_args, **_kwargs|
        raise "AvailableSlots should not be called by Confirm"
      end

      begin
        result = Bookings::Confirm.new(
          booking: booking,
          booking_params: {
            customer_first_name: "Léonard",
            customer_last_name: "Boisson",
            customer_email: "leo@example.com"
          }
        ).call

        assert result.success?
      ensure
        available_slots_singleton.alias_method :new, :new_without_confirm_available_slots_test
        available_slots_singleton.remove_method :new_without_confirm_available_slots_test
      end
    end
  end

  test "confirmation ignores bookings from another enseigne of the same client" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 13, 30, 0)

      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      @client.bookings.create!(
        enseigne: @other_enseigne,
        service: @service,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Other",
        customer_last_name: "User",
        customer_email: "other@example.com"
      )

      result = Bookings::Confirm.new(
        booking: booking,
        booking_params: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      ).call

      assert result.success?
      booking.reload
      assert_equal "confirmed", booking.booking_status
    end
  end

  test "fails when another booking with overlapping interval blocks confirmation" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      pending_start = Time.zone.local(2026, 3, 16, 10, 0, 0)
      pending_end   = pending_start + 30.minutes

      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: pending_start,
        booking_end_time: pending_end,
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      # Booking confirmé qui overlap partiellement (10:15–10:45)
      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 15, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 45, 0),
        booking_status: :confirmed,
        customer_first_name: "Other",
        customer_last_name: "User",
        customer_email: "other@example.com"
      )

      result = Bookings::Confirm.new(
        booking: booking,
        booking_params: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      ).call

      assert_not result.success?
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
      assert_equal "Le créneau sélectionné n'est plus disponible.", result.error_message

      booking.reload
      assert_equal "pending", booking.booking_status
    end
  end

  test "confirms booking when its interval starts at end of another booking" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      first_start = Time.zone.local(2026, 3, 16, 10, 0, 0)
      first_end   = first_start + 30.minutes

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: first_start,
        booking_end_time: first_end,
        booking_status: :confirmed,
        customer_first_name: "Other",
        customer_last_name: "User",
        customer_email: "other@example.com"
      )

      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: first_end,
        booking_end_time: first_end + 30.minutes,
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      result = Bookings::Confirm.new(
        booking: booking,
        booking_params: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      ).call

      assert result.success?
      booking.reload
      assert_equal "confirmed", booking.booking_status
    end
  end

  test "fails when booking params are invalid" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 14, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 14, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      result = Bookings::Confirm.new(
        booking: booking,
        booking_params: {
          customer_first_name: "",
          customer_last_name: "",
          customer_email: "not-an-email"
        }
      ).call

      assert_not result.success?
      assert_equal booking, result.booking
      assert_equal Bookings::Errors::FORM_INVALID, result.error_code
      assert_equal "Le formulaire contient des erreurs.", result.error_message

      booking.reload
      assert_equal "pending", booking.booking_status
    end
  end

  test "re-raises non allowlisted record not unique constraint errors during confirmation" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 15, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 15, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      unknown_constraint_name = "index_clients_on_slug"
      fake_pg_result = Object.new
      fake_pg_result.define_singleton_method(:error_field) do |_field|
        unknown_constraint_name
      end

      fake_pg_error = PG::UniqueViolation.new("duplicate key value violates unique constraint")
      fake_pg_error.define_singleton_method(:result) { fake_pg_result }

      unknown_constraint_error = ActiveRecord::RecordNotUnique.new("unknown unique constraint")
      unknown_constraint_error.define_singleton_method(:cause) { fake_pg_error }

      booking.define_singleton_method(:update!) do |_attrs|
        raise unknown_constraint_error
      end

      assert_raises ActiveRecord::RecordNotUnique do
        Bookings::Confirm.new(
          booking: booking,
          booking_params: {
            customer_first_name: "Léonard",
            customer_last_name: "Boisson",
            customer_email: "leo@example.com"
          }
        ).call
      end

      booking.reload
      assert_equal "pending", booking.booking_status
    end
  end

  test "maps allowlisted exclusion conflict to slot taken during confirm" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 15, 30, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 16, 0, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      constraint_name = "bookings_confirmed_no_overlapping_intervals_per_enseigne"
      fake_pg_result = Object.new
      fake_pg_result.define_singleton_method(:error_field) do |_field|
        constraint_name
      end

      fake_pg_error = PG::ExclusionViolation.new("conflicting key value violates exclusion constraint")
      fake_pg_error.define_singleton_method(:result) { fake_pg_result }

      conflict_error = ActiveRecord::StatementInvalid.new("overlap conflict")
      conflict_error.define_singleton_method(:cause) { fake_pg_error }

      booking.define_singleton_method(:update!) do |_attrs|
        raise conflict_error
      end

      result = Bookings::Confirm.new(
        booking: booking,
        booking_params: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      ).call

      assert_not result.success?
      assert_equal booking, result.booking
      assert_equal Bookings::Errors::SLOT_TAKEN_DURING_CONFIRM, result.error_code
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SLOT_TAKEN_DURING_CONFIRM), result.error_message

      booking.reload
      assert_equal "pending", booking.booking_status
    end
  end
end
