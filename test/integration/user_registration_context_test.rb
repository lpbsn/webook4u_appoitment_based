require "test_helper"

class UserRegistrationContextTest < ActionDispatch::IntegrationTest
  test "sign up from booking context creates user on current client" do
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
    assert_redirected_to "/#{client.slug}/bookings/pending-token"
  end

  test "sign up without client context does not create user" do
    assert_no_difference("User.count") do
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

    assert_redirected_to new_user_session_path
    assert_equal "Inscription impossible hors contexte client.", flash[:alert]
  end
end
