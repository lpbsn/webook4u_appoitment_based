require "test_helper"

class RoleNamespacesAccessTest < ActionDispatch::IntegrationTest
  setup do
    @client_one = Client.create!(name: "Client One", slug: "client-one-role-test")
    @client_two = Client.create!(name: "Client Two", slug: "client-two-role-test")

    @enseigne_one = @client_one.enseignes.create!(name: "Enseigne One", active: true)
    @enseigne_two = @client_two.enseignes.create!(name: "Enseigne Two", active: true)

    @service_one = @enseigne_one.services.create!(name: "Service One", duration_minutes: 30, price_cents: 2000)
    @service_two = @enseigne_two.services.create!(name: "Service Two", duration_minutes: 30, price_cents: 2000)

    @staff_one = @enseigne_one.staffs.create!(name: "Staff One", active: true)
    @staff_two = @enseigne_two.staffs.create!(name: "Staff Two", active: true)

    @admin = create_test_user(role: :admin, client: nil, email: "admin-scopes@example.com")
    @client_user = create_test_user(role: :client_user, client: @client_one, email: "client-user-scopes@example.com")
    @end_user = create_test_user(role: :user, client: nil, email: "end-user-scopes@example.com")
  end

  test "admin can access the global bookings list" do
    booking_one, booking_two = create_confirmed_bookings

    sign_in @admin
    get admin_bookings_path

    assert_response :success
    assert_includes response.body, booking_one.client.name
    assert_includes response.body, booking_two.client.name
    assert_not_includes response.body, "booking-back-link"
  end

  test "client user list is strictly scoped by client_id" do
    booking_one, booking_two = create_confirmed_bookings

    sign_in @client_user
    get client_bookings_path

    assert_response :success
    assert_includes response.body, booking_one.enseigne.name
    assert_not_includes response.body, booking_two.enseigne.name
    assert_not_includes response.body, "booking-back-link"
  end

  test "user list only includes confirmed bookings explicitly linked by user_id" do
    linked_confirmed, _other_client_confirmed = create_confirmed_bookings
    create_pending_booking_for(@end_user)
    create_anonymous_booking_with_same_email

    sign_in @end_user
    get user_bookings_path

    assert_response :success
    assert_includes response.body, linked_confirmed.enseigne.name
    assert_not_includes response.body, "Pending anonymous"
    assert_not_includes response.body, "Anonymous by email only"
    assert_not_includes response.body, "booking-back-link"
  end

  test "cross-namespace access is rejected server-side" do
    sign_in @client_user
    get admin_bookings_path
    assert_redirected_to client_root_path

    get user_bookings_path
    assert_redirected_to client_root_path

    sign_out @client_user
    sign_in @end_user
    get client_bookings_path
    assert_redirected_to user_root_path

    get admin_bookings_path
    assert_redirected_to user_root_path

    sign_out @end_user
    sign_in @admin
    get client_bookings_path
    assert_redirected_to admin_root_path

    get user_bookings_path
    assert_redirected_to admin_root_path
  end

  test "authenticated topbar exposes personal space link for each role" do
    sign_in @admin
    get admin_bookings_path
    assert_response :success
    assert_includes response.body, "🏠 Home"
    assert_includes response.body, "href=\"#{admin_root_path}\""

    sign_out @admin
    sign_in @client_user
    get client_bookings_path
    assert_response :success
    assert_includes response.body, "🏠 Home"
    assert_includes response.body, "href=\"#{client_root_path}\""

    sign_out @client_user
    sign_in @end_user
    get user_bookings_path
    assert_response :success
    assert_includes response.body, "🏠 Home"
    assert_includes response.body, "href=\"#{user_root_path}\""
  end

  test "public pending token flow stays outside role namespaces" do
    pending_booking = Booking.create!(
      client: @client_one,
      enseigne: @enseigne_one,
      service: @service_one,
      staff: @staff_one,
      user: nil,
      booking_start_time: Time.zone.now.change(sec: 0) + 1.day,
      booking_end_time: Time.zone.now.change(sec: 0) + 1.day + 30.minutes,
      booking_status: :pending,
      booking_expires_at: 5.minutes.from_now,
      pending_access_token: SecureRandom.urlsafe_base64(24)
    )

    get pending_booking_path(@client_one.slug, pending_booking.pending_access_token)
    assert_response :success

    sign_in @client_user
    get pending_booking_path(@client_one.slug, pending_booking.pending_access_token)
    assert_response :success
  end

  private

  def create_confirmed_bookings
    start_time_one = Time.zone.now.change(sec: 0) + 1.day
    start_time_two = Time.zone.now.change(sec: 0) + 2.days

    booking_one = Booking.create!(
      client: @client_one,
      enseigne: @enseigne_one,
      service: @service_one,
      staff: @staff_one,
      user: @end_user,
      booking_start_time: start_time_one,
      booking_end_time: start_time_one + 30.minutes,
      booking_status: :confirmed,
      customer_first_name: "Linked",
      customer_last_name: "User",
      customer_email: @end_user.email
    )

    booking_two = Booking.create!(
      client: @client_two,
      enseigne: @enseigne_two,
      service: @service_two,
      staff: @staff_two,
      user: nil,
      booking_start_time: start_time_two,
      booking_end_time: start_time_two + 30.minutes,
      booking_status: :confirmed,
      customer_first_name: "Client",
      customer_last_name: "Two",
      customer_email: "client-two@example.com"
    )

    [ booking_one, booking_two ]
  end

  def create_pending_booking_for(user)
    start_time = Time.zone.now.change(sec: 0) + 3.days

    Booking.create!(
      client: @client_one,
      enseigne: @enseigne_one,
      service: @service_one,
      staff: @staff_one,
      user: user,
      booking_start_time: start_time,
      booking_end_time: start_time + 30.minutes,
      booking_status: :pending,
      customer_first_name: "Pending",
      customer_last_name: "anonymous",
      customer_email: "pending@example.com",
      pending_access_token: SecureRandom.urlsafe_base64(24),
      booking_expires_at: 5.minutes.from_now
    )
  end

  def create_anonymous_booking_with_same_email
    start_time = Time.zone.now.change(sec: 0) + 4.days

    Booking.create!(
      client: @client_two,
      enseigne: @enseigne_two,
      service: @service_two,
      staff: @staff_two,
      user: nil,
      booking_start_time: start_time,
      booking_end_time: start_time + 30.minutes,
      booking_status: :confirmed,
      customer_first_name: "Anonymous",
      customer_last_name: "by email only",
      customer_email: @end_user.email
    )
  end
end
