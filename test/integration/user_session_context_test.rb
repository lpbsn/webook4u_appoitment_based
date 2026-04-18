require "test_helper"

class UserSessionContextTest < ActionDispatch::IntegrationTest
  test "user can sign in within the correct client context" do
    client = Client.create!(name: "Client A", slug: "client-a")
    user = User.create!(
      client: client,
      first_name: "Jean",
      last_name: "Dupont",
      email: "jean@example.com",
      password: "password"
    )

    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password"
      },
      redirect_to: "/#{client.slug}"
    }

    assert_redirected_to "/#{client.slug}"
  end

  test "user cannot sign in within another client context" do
    client_a = Client.create!(name: "Client A", slug: "client-a")
    client_b = Client.create!(name: "Client B", slug: "client-b")

    User.create!(
      client: client_a,
      first_name: "Jean",
      last_name: "Dupont",
      email: "jean@example.com",
      password: "password"
    )

    post user_session_path, params: {
      user: {
        email: "jean@example.com",
        password: "password"
      },
      redirect_to: "/#{client_b.slug}"
    }

    assert_response :unprocessable_content
  end

  test "sign in without client context fails" do
    client = Client.create!(name: "Client A", slug: "client-a")

    User.create!(
      client: client,
      first_name: "Jean",
      last_name: "Dupont",
      email: "jean@example.com",
      password: "password"
    )

    post user_session_path, params: {
      user: {
        email: "jean@example.com",
        password: "password"
      }
    }

    assert_redirected_to new_user_session_path

    follow_redirect!
    assert_response :success
    assert_includes response.body, "You must sign in from a client context."
  end

  test "sign in page renders without client context instead of redirecting in a loop" do
    get new_user_session_path

    assert_response :success
    assert_includes response.body, "You must sign in from a client context."
    assert_select ".booking-header-title", text: "Se connecter"
    assert_select "input.field-input", minimum: 2
  end

  test "sign up without client context redirects to sign in page" do
    get new_user_registration_path

    assert_redirected_to new_user_session_path

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Inscription impossible hors contexte client."
  end

  test "auth links preserve booking redirect_to across sign in and sign up pages" do
    client = Client.create!(name: "Client A", slug: "client-a")

    get new_user_session_path(redirect_to: "/#{client.slug}/bookings/pending-token")
    assert_response :success

    assert_select ".booking-header-title", text: "Se connecter"
    assert_select "a[href=?]", new_user_registration_path(redirect_to: "/#{client.slug}/bookings/pending-token")

    get new_user_registration_path(redirect_to: "/#{client.slug}/bookings/pending-token")
    assert_response :success

    assert_select ".booking-header-title", text: "Créer un compte"
    assert_select "input.field-input", minimum: 5
    assert_select "a[href=?]", new_user_session_path(redirect_to: "/#{client.slug}/bookings/pending-token")
  end
end
