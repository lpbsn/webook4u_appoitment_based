require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "client is required" do
    user = User.new(
      email: "no-client@example.com",
      first_name: "Morora",
      last_name: "Tatante",
      password: "password123"
    )

    assert_not user.valid?
    assert_includes user.errors[:client], "must exist"
  end

  test "email must be unique within the same client" do
    duplicate = User.new(
      client: clients(:one),
      email: users(:one).email,
      first_name: "Morora",
      last_name: "Tatante",
      password: "password123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end
end
