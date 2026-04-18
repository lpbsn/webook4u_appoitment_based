require "test_helper"

class BookingAuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @client = clients(:one)
    @enseigne = enseignes(:one)
    @service = services(:one)
    @user = users(:one)

    start_time = Time.zone.now.change(sec: 0) + 1.day

    @booking = Booking.create!(
      client: @client,
      enseigne: @enseigne,
      service: @service,
      user: nil,
      booking_start_time: start_time,
      booking_end_time: start_time + @service.duration_minutes.minutes,
      booking_status: :pending,
      booking_expires_at: 5.minutes.from_now,
      pending_access_token: SecureRandom.uuid
    )
  end

  test "non authenticated user is redirected back to pending booking after sign in" do
    get pending_booking_path(@client.slug, @booking.pending_access_token)
    assert_redirected_to new_user_session_path

    follow_redirect!
    assert_response :success
    assert_includes response.body, "You need to sign in or sign up before continuing."

    get new_user_session_path(
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    )
    assert_response :success
    assert_select "a[href=?]", new_user_registration_path(
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    )

    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password123"
      },
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    }

    assert_redirected_to pending_booking_path(@client.slug, @booking.pending_access_token)

    follow_redirect!
    assert_response :success
    assert_match @user.email, response.body
  end

  test "non authenticated user is redirected back to pending booking after sign up" do
    get new_user_registration_path(
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    )
    assert_response :success

    post user_registration_path, params: {
      user: {
        last_name: "Doe",
        first_name: "Jane",
        email: "jane.booking@example.com",
        password: "password123",
        password_confirmation: "password123"
      },
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    }

    assert_redirected_to pending_booking_path(@client.slug, @booking.pending_access_token)

    follow_redirect!
    assert_response :success
    assert_match "jane.booking@example.com", response.body
  end

  test "signed in user who signs out from pending booking is redirected back to pending booking after signing in again" do
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password123"
      },
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    }
    assert_redirected_to pending_booking_path(@client.slug, @booking.pending_access_token)

    follow_redirect!
    assert_response :success

    delete destroy_user_session_path, params: {
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    }

    assert_redirected_to new_user_session_path(
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    )

    follow_redirect!
    assert_response :success

    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password123"
      },
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    }

    assert_redirected_to pending_booking_path(@client.slug, @booking.pending_access_token)

    follow_redirect!
    assert_response :success
    assert_match @user.email, response.body
  end

  test "signed in user from another client is signed out and redirected to contextualized sign in" do
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

    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password123"
      },
      redirect_to: pending_booking_path(@client.slug, @booking.pending_access_token)
    }
    assert_redirected_to pending_booking_path(@client.slug, @booking.pending_access_token)

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
