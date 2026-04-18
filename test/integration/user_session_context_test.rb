require "test_helper"

class UserSessionContextTest < ActionDispatch::IntegrationTest
  test "user can sign in within the correct client context" do
    client = Client.create!(name: "Client A", slug: "client-a")
    user = User.create!(
      client: client,
      role: :client_user,
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

    assert_redirected_to client_root_path
  end

  test "user cannot sign in within another client context" do
    client_a = Client.create!(name: "Client A", slug: "client-a")
    client_b = Client.create!(name: "Client B", slug: "client-b")

    User.create!(
      client: client_a,
      role: :client_user,
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

  test "client user sign in without client context redirects to client homepage" do
    client = Client.create!(name: "Client A", slug: "client-a")

    User.create!(
      client: client,
      role: :client_user,
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

    assert_redirected_to client_root_path
  end

  test "unknown email without client context returns generic auth error" do
    post user_session_path, params: {
      user: {
        email: "unknown-user@example.com",
        password: "password"
      }
    }

    assert_response :unprocessable_content
    assert_includes response.body, "Invalid email or password."
  end

  test "sign in page renders without client context instead of redirecting in a loop" do
    get new_user_session_path

    assert_response :success
    assert_select ".booking-header-title", text: "Se connecter"
    assert_select "input.field-input", minimum: 2
  end

  test "sign up page is accessible without client context" do
    get new_user_registration_path

    assert_response :success
    assert_select ".booking-header-title", text: "Créer un compte"
  end

  test "admin can sign in without client context" do
    admin = users(:admin)

    post user_session_path, params: {
      user: {
        email: admin.email,
        password: "password123"
      }
    }

    assert_redirected_to admin_root_path
  end

  test "global user without client can sign in without client context" do
    user = User.create!(
      role: :user,
      active: true,
      client: nil,
      first_name: "Global",
      last_name: "User",
      email: "global.user@example.com",
      password: "password"
    )

    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password"
      }
    }

    assert_redirected_to user_root_path
  end

  test "user role with client can sign in without client context" do
    client = Client.create!(name: "Client A", slug: "client-a-user-role")
    user = User.create!(
      role: :user,
      active: true,
      client: client,
      first_name: "Scoped",
      last_name: "User",
      email: "scoped.user@example.com",
      password: "password"
    )

    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password"
      }
    }

    assert_redirected_to user_root_path
  end

  test "inactive account cannot sign in" do
    client = Client.create!(name: "Client A", slug: "client-a")
    user = User.create!(
      client: client,
      role: :client_user,
      active: false,
      first_name: "Jean",
      last_name: "Dupont",
      email: "inactive-user@example.com",
      password: "password"
    )

    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password"
      },
      redirect_to: "/#{client.slug}"
    }

    assert_redirected_to new_user_session_path

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Your account is inactive."
  end

  test "inactive admin cannot sign in" do
    admin = User.create!(
      role: :admin,
      active: false,
      client: nil,
      first_name: "Inactive",
      last_name: "Admin",
      email: "inactive-admin@example.com",
      password: "password"
    )

    post user_session_path, params: {
      user: {
        email: admin.email,
        password: "password"
      }
    }

    assert_redirected_to new_user_session_path

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Your account is inactive."
  end

  test "inactive global user cannot sign in" do
    user = User.create!(
      role: :user,
      active: false,
      client: nil,
      first_name: "Inactive",
      last_name: "User",
      email: "inactive-global-user@example.com",
      password: "password"
    )

    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password"
      }
    }

    assert_redirected_to new_user_session_path

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Your account is inactive."
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
