require "test_helper"

class BookingDuplicatesFlowTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(
      name: "Le Salon Des gâté",
      slug: "salon-des-gate"
    )

    @enseigne = @client.enseignes.create!(
      name: "Enseigne principale"
    )

    @service = @enseigne.services.create!(
      name: "Coupe homme",
      duration_minutes: 30,
      price_cents: 2500
    )
    @staff = @enseigne.staffs.create!(name: "Staff duplicates", active: true)

    create_weekday_opening_hours_for_enseigne(@enseigne)
    create_weekday_staff_availabilities_for(@staff)
    StaffServiceCapability.create!(staff: @staff, service: @service)
    ServiceAssignmentCursor.find_or_create_by!(service: @service)
  end

  # =========================================================
  # Un créneau déjà réservé en confirmed doit être refusé
  # =========================================================
  test "create_pending refuses a slot already confirmed" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Leonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      assert_no_difference "Booking.count" do
        post service_bookings_path(@client.slug, @service),
             params: { start_time: slot, enseigne_id: @enseigne.id }
      end

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: slot.to_date
      )
    end
  end

  # =========================================================
  # Un créneau déjà réservé en pending non expiré doit être refusé
  # =========================================================
  test "create_pending refuses a slot already blocked by active pending" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 11, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      assert_no_difference "Booking.count" do
        post service_bookings_path(@client.slug, @service),
             params: { start_time: slot, enseigne_id: @enseigne.id }
      end

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: slot.to_date
      )
    end
  end

  # =========================================================
  # Un pending expiré ne doit plus bloquer le créneau
  # =========================================================
  test "create_pending allows a slot previously blocked by expired pending" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 12, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )

      assert_difference "Booking.count", 1 do
        post service_bookings_path(@client.slug, @service),
             params: { start_time: slot, enseigne_id: @enseigne.id }
      end

      booking = Booking.last
      assert_redirected_to pending_booking_path(@client.slug, booking.pending_access_token)
      assert_equal "pending", booking.booking_status
      assert_equal slot, booking.booking_start_time
    end
  end

  # =========================================================
  # Si un autre booking a confirmé le même créneau entre-temps,
  # la confirmation du booking courant doit être refusée
  # =========================================================
  test "create refuses confirmation when another booking confirmed the same slot in the meantime" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 13, 0, 0)

      pending_booking = @client.bookings.create!(
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

      post confirm_booking_path(@client.slug, pending_booking.pending_access_token), params: {
        booking: {
          customer_first_name: "Leonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      }

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: slot.to_date
      )

      pending_booking.reload
      assert_equal "pending", pending_booking.booking_status
      assert_nil pending_booking.customer_first_name
      assert_nil pending_booking.customer_last_name
    end
  end

  # =========================================================
  # Vérifie la protection finale côté base de données :
  # impossible d'avoir 2 confirmed sur le même créneau
  # dans la même enseigne
  # =========================================================
  test "database overlap protection prevents duplicate confirmed bookings on overlapping intervals" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 14, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Leonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      error = assert_raises ActiveRecord::StatementInvalid do
        @client.bookings.create!(
          enseigne: @enseigne,
          service: @service,
          booking_start_time: slot + 15.minutes,
          booking_end_time: slot + 45.minutes,
          booking_status: :confirmed,
          customer_first_name: "Other",
          customer_last_name: "User",
          customer_email: "other@example.com"
        )
      end

      assert_instance_of PG::ExclusionViolation, error.cause
    end
  end

  test "same confirmed slot is allowed in another enseigne of the same client" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 14, 30, 0)
      other_enseigne = @client.enseignes.create!(name: "Enseigne secondaire")
      other_service = other_enseigne.services.create!(
        name: "Coupe femme",
        duration_minutes: 30,
        price_cents: 3500
      )

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Leonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      assert_nothing_raised do
        @client.bookings.create!(
          enseigne: other_enseigne,
          service: other_service,
          booking_start_time: slot,
          booking_end_time: slot + 30.minutes,
          booking_status: :confirmed,
          customer_first_name: "Other",
          customer_last_name: "User",
          customer_email: "other@example.com"
        )
      end
    end
  end

  # =========================================================
  # Pour un autre client, le même créneau doit rester possible
  # (l'unicité n'est plus par client)
  # =========================================================
  test "same slot is allowed for another client" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      other_client = Client.create!(
        name: "Maigris Mon Gros",
        slug: "maigris-mon-gros"
      )
      other_enseigne = other_client.enseignes.create!(name: "Enseigne MG")

      other_service = other_enseigne.services.create!(
        name: "Séance individuelle",
        duration_minutes: 30,
        price_cents: 4000
      )

      slot = Time.zone.local(2026, 3, 16, 15, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Leonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      assert_nothing_raised do
        other_client.bookings.create!(
          enseigne: other_enseigne,
          service: other_service,
          booking_start_time: slot,
          booking_end_time: slot + 30.minutes,
          booking_status: :confirmed,
          customer_first_name: "Other",
          customer_last_name: "User",
          customer_email: "other@example.com"
        )
      end
    end
  end
end
