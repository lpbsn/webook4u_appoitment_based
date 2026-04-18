require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email must be globally unique" do
    duplicate = User.new(
      email: users(:one).email,
      first_name: "Morora",
      last_name: "Tatante",
      role: :user,
      active: true,
      password: "password123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "client user requires a client" do
    user = User.new(
      email: "client-user-without-client@example.com",
      first_name: "Morora",
      last_name: "Tatante",
      role: :client_user,
      active: true,
      password: "password123"
    )

    assert_not user.valid?
    assert_includes user.errors[:client], "can't be blank"
  end

  test "admin cannot be attached to a client" do
    user = User.new(
      client: clients(:one),
      email: "admin-with-client@example.com",
      first_name: "Morora",
      last_name: "Tatante",
      role: :admin,
      active: true,
      password: "password123"
    )

    assert_not user.valid?
    assert_includes user.errors[:client], "must be blank"
  end

  test "find_for_authentication returns global user without client context" do
    user = User.create!(
      role: :user,
      active: true,
      client: nil,
      first_name: "Global",
      last_name: "User",
      email: "global-auth-user@example.com",
      password: "password123"
    )

    Current.set(auth_client: nil) do
      found = User.find_for_authentication(email: user.email)
      assert_equal user, found
    end
  end
end
