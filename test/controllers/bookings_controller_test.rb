# frozen_string_literal: true

require "test_helper"

class BookingsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(
      name: "Le Salon Des gâté",
      slug: "salon-des-gate"
    )

    @enseigne = @client.enseignes.create!(
      name: "Enseigne principale",
      full_address: "1 rue de Paris"
    )

    @service = @enseigne.services.create!(
      name: "Coupe homme",
      duration_minutes: 30,
      price_cents: 2500
    )

    @staff = @enseigne.staffs.create!(name: "Staff controller", active: true)
    @staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: @staff, service: @service)
    ServiceAssignmentCursor.find_or_create_by!(service: @service)

    create_weekday_opening_hours_for_enseigne(@enseigne)
  end

  # =========================================================
  # POST #create_pending
  # =========================================================

  test "old GET booking route is no longer recognized by router" do
    old_path = "/#{@client.slug}/services/#{@service.id}/bookings/new"

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(old_path, method: :get)
    end
  end

  test "POST #create_pending creates a pending booking and redirects to the pending booking page" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      assert_difference "Booking.count", 1 do
        post service_bookings_path(@client.slug, @service),
             params: { start_time: slot, enseigne_id: @enseigne.id }
      end

      booking = Booking.last
      assert_redirected_to pending_booking_path(@client.slug, booking.pending_access_token)

      follow_redirect!
      assert_response :success

      assert_equal @client.id, booking.client_id
      assert_equal @enseigne.id, booking.enseigne_id
      assert_equal @service.id, booking.service_id
      assert_equal "pending", booking.booking_status
      assert_equal slot, booking.booking_start_time
      assert_includes response.body, @enseigne.name
      assert_includes response.body, @enseigne.full_address
      assert_includes response.body, "Valider la réservation"
    end
  end

  test "GET #show displays the form for an existing pending booking" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      get pending_booking_path(@client.slug, booking.pending_access_token)

      assert_response :success
      assert_includes response.body, @enseigne.name
      assert_includes response.body, @enseigne.full_address
      assert_includes response.body, "Valider la réservation"
    end
  end

  test "GET #show redirects to client page with SESSION_EXPIRED when pending booking is expired" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )

      get pending_booking_path(@client.slug, booking.pending_access_token)

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED), flash[:alert]
    end
  end

  test "GET #show redirects to client page with SESSION_EXPIRED after expired pending booking has been purged" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )
      token = booking.pending_access_token

      Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now)

      get pending_booking_path(@client.slug, token)

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED), flash[:alert]
    end
  end

  test "GET #show expired drops inactive enseigne from redirect context before purge" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )
      @enseigne.update!(active: false)

      get pending_booking_path(@client.slug, booking.pending_access_token)

      assert_redirected_to public_client_path(
        @client.slug,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED), flash[:alert]
    end
  end

  test "GET #show expired drops inactive enseigne from redirect context after purge" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 10, 30, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )
      token = booking.pending_access_token
      @enseigne.update!(active: false)

      Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now)

      get pending_booking_path(@client.slug, token)

      assert_redirected_to public_client_path(
        @client.slug,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED), flash[:alert]
    end
  end

  test "POST #create_pending redirects to client page with alert when start_time is invalid" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      post service_bookings_path(@client.slug, @service),
           params: { start_time: "invalid", enseigne_id: @enseigne.id }

      assert_redirected_to public_client_path(@client.slug, enseigne_id: @enseigne.id, service_id: @service.id)
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::INVALID_SLOT), flash[:alert]
    end
  end

  test "POST #create_pending keeps date context on redirect when start_time is invalid" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      post service_bookings_path(@client.slug, @service),
           params: { start_time: "invalid", enseigne_id: @enseigne.id, date: "2026-03-16" }

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
    end
  end

  test "POST #create_pending redirects to client page with alert when slot is unavailable" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Jean",
        customer_last_name: "Dupont",
        customer_email: "jean@example.com"
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
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SLOT_UNAVAILABLE), flash[:alert]
    end
  end

  test "POST #create_pending redirects to client page with alert when slot is not generated by the system" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot_not_in_grid = Time.zone.local(2026, 3, 16, 8, 0, 0)

      assert_no_difference "Booking.count" do
        post service_bookings_path(@client.slug, @service),
             params: { start_time: slot_not_in_grid, enseigne_id: @enseigne.id }
      end

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SLOT_NOT_BOOKABLE), flash[:alert]
    end
  end

  test "POST #create_pending redirects to client page with alert when start_time is beyond max_future_days" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      time_beyond = (Time.zone.now + (BookingRules.max_future_days + 1).days).iso8601

      post service_bookings_path(@client.slug, @service),
           params: { start_time: time_beyond, enseigne_id: @enseigne.id }

      assert_redirected_to public_client_path(@client.slug, enseigne_id: @enseigne.id, service_id: @service.id)
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::INVALID_SLOT), flash[:alert]
    end
  end

  # =========================================================
  # POST #create
  # =========================================================

  test "POST #create confirms a valid pending booking and redirects to success" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      post confirm_booking_path(@client.slug, booking.pending_access_token), params: {
        booking: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      }

      booking.reload
      assert_redirected_to booking_success_path(@client.slug, booking.confirmation_token)
      assert_equal "confirmed", booking.booking_status
      assert_equal "Léonard", booking.customer_first_name
      assert_equal "Boisson", booking.customer_last_name
      assert_equal "leo@example.com", booking.customer_email
    end
  end

  test "POST #create re-renders new with status 422 when form is invalid" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 14, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 14, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      post confirm_booking_path(@client.slug, booking.pending_access_token), params: {
        booking: {
          customer_first_name: "",
          customer_last_name: "",
          customer_email: "not-an-email"
        }
      }

      assert_response :unprocessable_entity

      booking.reload
      assert_equal "pending", booking.booking_status
      assert_nil booking.customer_first_name
    end
  end

  test "POST #create redirects to client page with alert when booking is not confirmable" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 12, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 12, 30, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )

      post confirm_booking_path(@client.slug, booking.pending_access_token), params: {
        booking: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      }

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED), flash[:alert]

      booking.reload
      assert_equal "pending", booking.booking_status
    end
  end

  test "POST #create redirects to client page with SESSION_EXPIRED after expired pending booking has been purged" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 12, 30, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 13, 0, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )
      token = booking.pending_access_token

      Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now)

      post confirm_booking_path(@client.slug, token), params: {
        booking: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      }

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED), flash[:alert]
    end
  end

  test "POST #create returns 404 for confirmed booking token" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 13, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 13, 30, 0),
        booking_status: :confirmed,
        pending_access_token: SecureRandom.urlsafe_base64(24),
        customer_first_name: "Léonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      post confirm_booking_path(@client.slug, booking.pending_access_token), params: {
        booking: {
          customer_first_name: "Test",
          customer_last_name: "User",
          customer_email: "test@example.com"
        }
      }

      assert_response :not_found
    end
  end

  test "POST #create drops inactive enseigne from redirect context when booking is no longer confirmable" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 13, 30, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 14, 0, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )
      @enseigne.update!(active: false)

      post confirm_booking_path(@client.slug, booking.pending_access_token), params: {
        booking: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      }

      assert_redirected_to public_client_path(
        @client.slug,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
    end
  end

  test "POST #create after purge drops inactive enseigne from redirect context" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 14, 30, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 15, 0, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )
      token = booking.pending_access_token
      @enseigne.update!(active: false)

      Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now)

      post confirm_booking_path(@client.slug, token), params: {
        booking: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      }

      assert_redirected_to public_client_path(
        @client.slug,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED), flash[:alert]
    end
  end

  test "POST #create_pending returns 404 for unknown client slug" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)
      post service_bookings_path("slug-inconnu-xyz", @service),
           params: { start_time: slot, enseigne_id: @enseigne.id }
      assert_response :not_found
    end
  end

  test "POST #create returns 404 for unknown client slug" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      post confirm_booking_path("slug-inconnu-xyz", booking.pending_access_token), params: {
        booking: { customer_first_name: "A", customer_last_name: "B", customer_email: "a@b.com" }
      }
      assert_response :not_found
    end
  end

  test "POST #create returns 404 for booking not belonging to client" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      other_client = Client.create!(name: "Autre", slug: "autre-404")
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      post confirm_booking_path(other_client.slug, booking.pending_access_token), params: {
        booking: { customer_first_name: "A", customer_last_name: "B", customer_email: "a@b.com" }
      }
      assert_response :not_found
    end
  end

  test "GET #show returns 404 for unknown client slug" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      get pending_booking_path("slug-inconnu-xyz", booking.pending_access_token)
      assert_response :not_found
    end
  end

  test "GET #show returns 404 for booking not belonging to client" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      other_client = Client.create!(name: "Autre", slug: "autre-show-404")
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      get pending_booking_path(other_client.slug, booking.pending_access_token)
      assert_response :not_found
    end
  end

  test "GET #show returns 404 for confirmed booking" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 11, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 11, 30, 0),
        booking_status: :confirmed,
        pending_access_token: SecureRandom.urlsafe_base64(24),
        customer_first_name: "Léonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      get pending_booking_path(@client.slug, booking.pending_access_token)
      assert_response :not_found
    end
  end

  test "GET #show returns 404 for invalid token" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      get pending_booking_path(@client.slug, "token-invalide")
      assert_response :not_found
    end
  end

  test "POST #create returns 404 for invalid token" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      post confirm_booking_path(@client.slug, "token-invalide"), params: {
        booking: { customer_first_name: "A", customer_last_name: "B", customer_email: "a@b.com" }
      }
      assert_response :not_found
    end
  end

  test "old tombstoned token cannot pollute a new public booking cycle" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      expired_booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 16, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 16, 30, 0),
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )
      expired_token = expired_booking.pending_access_token

      Bookings::PurgeExpiredPending.call(cutoff: Time.zone.now)

      new_booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 17, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 17, 30, 0),
        booking_status: :pending,
        booking_expires_at: 5.minutes.from_now
      )

      assert_not_equal expired_token, new_booking.pending_access_token

      get pending_booking_path(@client.slug, expired_token)
      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED), flash[:alert]

      get pending_booking_path(@client.slug, new_booking.pending_access_token)
      assert_response :success
      assert_includes response.body, "Valider la réservation"

      post confirm_booking_path(@client.slug, expired_token), params: {
        booking: {
          customer_first_name: "Legacy",
          customer_last_name: "Token",
          customer_email: "legacy@example.com"
        }
      }

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )
      follow_redirect!
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED), flash[:alert]

      post confirm_booking_path(@client.slug, new_booking.pending_access_token), params: {
        booking: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      }

      new_booking.reload
      assert_equal "confirmed", new_booking.booking_status
      assert_redirected_to booking_success_path(@client.slug, new_booking.confirmation_token)
    end
  end

  # =========================================================
  # GET #success
  # =========================================================

  test "GET #success displays success page for booking belonging to client" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      booking = @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: Time.zone.local(2026, 3, 16, 15, 0, 0),
        booking_end_time: Time.zone.local(2026, 3, 16, 15, 30, 0),
        booking_status: :confirmed,
        confirmation_token: SecureRandom.uuid,
        customer_first_name: "Léonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      get booking_success_path(@client.slug, booking.confirmation_token)

      assert_response :success
      assert_includes response.body, @enseigne.name
      assert_includes response.body, @enseigne.full_address
    end
  end

  test "GET #success returns 404 for unknown confirmation token" do
    get booking_success_path(@client.slug, "token-qui-nexiste-pas")
    assert_response :not_found
  end

  test "GET #success returns 404 when booking does not belong to client" do
    other_client = Client.create!(name: "Autre", slug: "autre-client")
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      staff: @staff,
      booking_start_time: Time.zone.local(2026, 3, 16, 16, 0, 0),
      booking_end_time: Time.zone.local(2026, 3, 16, 16, 30, 0),
      booking_status: :confirmed,
      confirmation_token: SecureRandom.uuid,
      customer_first_name: "Léonard",
      customer_last_name: "Boisson",
      customer_email: "leo@example.com"
    )

    get booking_success_path(other_client.slug, booking.confirmation_token)

    assert_response :not_found
  end

  test "GET #success still works when booking enseigne has been deactivated" do
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: @service,
      staff: @staff,
      booking_start_time: Time.zone.local(2026, 3, 16, 17, 0, 0),
      booking_end_time: Time.zone.local(2026, 3, 16, 17, 30, 0),
      booking_status: :confirmed,
      confirmation_token: SecureRandom.uuid,
      customer_first_name: "Léonard",
      customer_last_name: "Boisson",
      customer_email: "leo@example.com"
    )
    @enseigne.update!(active: false)

    get booking_success_path(@client.slug, booking.confirmation_token)

    assert_response :success
    assert_includes response.body, @enseigne.name
  end

  test "POST #create_pending returns 404 for inactive enseigne" do
    inactive_enseigne = @client.enseignes.create!(name: "Inactive", full_address: "2 rue de Paris", active: false)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)
      post service_bookings_path(@client.slug, @service),
           params: { start_time: slot, enseigne_id: inactive_enseigne.id }
      assert_response :not_found
    end
  end

  test "POST #create_pending returns 404 when service does not belong to selected enseigne" do
    other_enseigne = @client.enseignes.create!(name: "Enseigne secondaire", full_address: "3 rue de Paris", active: true)
    other_service = other_enseigne.services.create!(name: "Coloration", duration_minutes: 45, price_cents: 5000)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)
      post service_bookings_path(@client.slug, other_service),
           params: { start_time: slot, enseigne_id: @enseigne.id }
      assert_response :not_found
    end
  end
end
