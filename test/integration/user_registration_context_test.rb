require "test_helper"

class UserRegistrationContextTest < ActionDispatch::IntegrationTest
  test "sign up from booking context creates a booker on current client and redirects to role dashboard" do
    client = clients(:one)

    assert_difference("User.count", 1) do
      post user_registration_path, params: {
        redirect_to: "/#{client.slug}/bookings/pending-token",
        user: {
          last_name: "Chopupapi",
          first_name: "Mougnagno",
          email: "choupapi.mougnagno@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    user = User.order(:created_at).last
    assert_equal client.id, user.client_id
    assert_equal "booker", user.role
    assert_redirected_to user_root_path
  end

  test "sign up without client context creates a global booker account" do
    assert_difference("User.count", 1) do
      post user_registration_path, params: {
        user: {
          last_name: "Choupapi",
          first_name: "Mougnagno",
          email: "hors.contexte@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    user = User.order(:created_at).last
    assert_nil user.client_id
    assert_equal "booker", user.role
    assert_redirected_to user_root_path
  end
end
