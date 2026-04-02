# frozen_string_literal: true

require "test_helper"

class BookingFlowTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(
      name: "Le Salon Des gâté",
      slug: "salon-des-gate"
    )
    create_weekday_opening_hours_for(@client)
    @enseigne = @client.enseignes.create!(name: "Enseigne principale", full_address: "1 rue de Paris")

    @service = @enseigne.services.create!(
      name: "Coupe homme",
      duration_minutes: 30,
      price_cents: 2500
    )
  end

  test "complete booking flow from public page to confirmation and success" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      # 1. Accès à la page publique du client
      get public_client_path(@client.slug)
      assert_response :success

      # 2. Sélection service + date pour afficher les créneaux (16 mars 2026 = lundi)
      date_param = "2026-03-16"
      get public_client_path(@client.slug, enseigne_id: @enseigne.id, service_id: @service.id, date: date_param)
      assert_response :success

      # 3. Création explicite du pending via POST (créneau 10h00 = valide dans la grille)
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      assert_difference "Booking.count", 1 do
        post service_bookings_path(@client.slug, @service),
             params: { start_time: slot, enseigne_id: @enseigne.id, date: date_param }
      end

      # 4. Vérification qu’un booking pending a été créé
      booking = Booking.last
      assert_redirected_to pending_booking_path(@client.slug, booking.pending_access_token)

      follow_redirect!
      assert_response :success
      assert_includes response.body, "Valider la réservation"

      assert_equal @client.id, booking.client_id
      assert_equal @enseigne.id, booking.enseigne_id
      assert_equal @service.id, booking.service_id
      assert_equal "pending", booking.booking_status, "After POST create_pending, booking should be pending"
      assert_equal slot, booking.booking_start_time

      # 5. Soumission valide via POST confirm
      post confirm_booking_path(@client.slug, booking.pending_access_token), params: {
        booking: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      }

      # 6. Redirection vers booking_success_path
      booking.reload
      assert_redirected_to booking_success_path(@client.slug, booking.confirmation_token)

      follow_redirect!
      assert_response :success

      # 7. Vérification finale : booking confirmé en base
      assert_equal "confirmed", booking.booking_status, "After confirm POST, booking should be confirmed"
      assert_equal "Léonard", booking.customer_first_name
      assert_equal "leo@example.com", booking.customer_email

      # 7. (suite) Éléments clés présents sur la page success
      assert_includes response.body, "Votre réservation est confirmée"
      assert_includes response.body, @client.name
      assert_includes response.body, @enseigne.name
      assert_includes response.body, @service.name
    end
  end

  test "complete booking flow keeps the selected enseigne when several active enseignes exist" do
    other_enseigne = @client.enseignes.create!(name: "Enseigne secondaire", full_address: "2 rue de Paris")

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      get public_client_path(@client.slug)
      assert_response :success
      assert_select "h2", text: "1. Choisissez une enseigne"

      get public_client_path(@client.slug, enseigne_id: other_enseigne.id)
      assert_response :success
      assert_includes response.body, other_enseigne.name

      get public_client_path(@client.slug, enseigne_id: other_enseigne.id, service_id: @service.id, date: "2026-03-16")
      assert_response :success

      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      assert_difference "Booking.count", 1 do
        post service_bookings_path(@client.slug, @service),
             params: { start_time: slot, enseigne_id: other_enseigne.id, date: "2026-03-16" }
      end

      booking = Booking.last
      assert_redirected_to pending_booking_path(@client.slug, booking.pending_access_token)
      follow_redirect!
      assert_response :success
      assert_equal other_enseigne.id, booking.enseigne_id

      post confirm_booking_path(@client.slug, booking.pending_access_token), params: {
        booking: {
          customer_first_name: "Léonard",
          customer_last_name: "Boisson",
          customer_email: "leo@example.com"
        }
      }

      booking.reload
      assert_redirected_to booking_success_path(@client.slug, booking.confirmation_token)
      follow_redirect!
      assert_response :success
      assert_includes response.body, other_enseigne.name
      assert_includes response.body, other_enseigne.full_address
    end
  end

  test "public flow redirects back to the selected page with slot not bookable alert" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      date_param = "2026-03-16"
      slot_not_in_schedule_grid = Time.zone.local(2026, 3, 16, 8, 0, 0)

      assert_no_difference "Booking.count" do
        post service_bookings_path(@client.slug, @service),
             params: { start_time: slot_not_in_schedule_grid, enseigne_id: @enseigne.id, date: date_param }
      end

      assert_redirected_to public_client_path(
        @client.slug,
        enseigne_id: @enseigne.id,
        service_id: @service.id,
        date: Date.new(2026, 3, 16)
      )

      follow_redirect!
      assert_response :success
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SLOT_NOT_BOOKABLE), flash[:alert]
      assert_includes response.body, @enseigne.name
      assert_includes response.body, @service.name
    end
  end

  test "public flow redirects back with slot unavailable alert when confirmation is blocked" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      date_param = "2026-03-16"
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      post service_bookings_path(@client.slug, @service),
           params: { start_time: slot, enseigne_id: @enseigne.id, date: date_param }

      booking = Booking.last

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
      assert_response :success
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SLOT_UNAVAILABLE), flash[:alert]

      booking.reload
      assert_equal "pending", booking.booking_status
    end
  end

  test "public flow redirects back with session expired alert when pending expires before confirmation" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      date_param = "2026-03-16"
      slot = Time.zone.local(2026, 3, 16, 11, 0, 0)

      post service_bookings_path(@client.slug, @service),
           params: { start_time: slot, enseigne_id: @enseigne.id, date: date_param }

      booking = Booking.last
      booking.update!(booking_expires_at: 1.minute.ago)

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
      assert_response :success
      assert_equal Bookings::Errors.message_for(Bookings::Errors::SESSION_EXPIRED), flash[:alert]

      booking.reload
      assert_equal "pending", booking.booking_status
    end
  end
end
