require "test_helper"

class BookingAuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @client = clients(:one)
    @enseigne = enseignes(:one)
    @service = services(:one)
    @user = users(:one)
    @staff = @enseigne.staffs.create!(name: "Staff auth flow", active: true)
    @staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: @staff, service: @service)
    ServiceAssignmentCursor.find_or_create_by!(service: @service)

    start_time = Time.zone.now.change(sec: 0) + 1.day

    @booking = Booking.create!(
      client: @client,
      enseigne: @enseigne,
      service: @service,
      staff: @staff,
      user: nil,
      booking_start_time: start_time,
      booking_end_time: start_time + @service.duration_minutes.minutes,
      booking_status: :pending,
      booking_expires_at: 5.minutes.from_now,
      pending_access_token: SecureRandom.uuid
    )
  end

  test "non authenticated user can access pending booking page directly" do
    get pending_booking_path(@client.slug, @booking.pending_access_token)
    assert_response :success
    assert_includes response.body, "Valider la réservation"
  end

  test "non authenticated user can confirm a pending booking" do
    post confirm_booking_path(@client.slug, @booking.pending_access_token), params: {
      booking: {
        customer_first_name: "Jane",
        customer_last_name: "Doe",
        customer_email: "jane.booking@example.com"
      }
    }

    @booking.reload
    assert_equal "confirmed", @booking.booking_status
    assert_redirected_to booking_success_path(@client.slug, @booking.confirmation_token)
  end

  test "signed in user from another client is still signed out on mismatched client context" do
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password123"
      },
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    }
    assert_redirected_to client_root_path

    other_client = clients(:two)
    other_enseigne = enseignes(:two)
    other_service = services(:two)

    start_time = Time.zone.now.change(sec: 0) + 2.days

    other_booking = Booking.create!(
      client: other_client,
      enseigne: other_enseigne,
      service: other_service,
      user: nil,
      booking_start_time: start_time,
      booking_end_time: start_time + other_service.duration_minutes.minutes,
      booking_status: :pending,
      booking_expires_at: 5.minutes.from_now,
      pending_access_token: SecureRandom.uuid
    )

    get pending_booking_path(other_client.slug, other_booking.pending_access_token)

    assert_redirected_to new_user_session_path(
      redirect_to: pending_booking_path(other_client.slug, other_booking.pending_access_token)
    )

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Your session does not match this booking context. Please sign in again."
    assert_select "a[href=?]", new_user_registration_path(
      redirect_to: pending_booking_path(other_client.slug, other_booking.pending_access_token)
    )
  end
end
