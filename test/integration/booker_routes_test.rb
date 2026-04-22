require "test_helper"

class BookerRoutesTest < ActionDispatch::IntegrationTest
  test "booker namespace uses /booker paths and helpers" do
    assert_equal "/booker", booker_root_path
    assert_equal "/booker/bookings", booker_bookings_path

    get booker_root_path
    assert_redirected_to new_user_session_path
  end

  test "legacy user root helper is no longer available" do
    assert_raises(NameError) { user_root_path }
  end
end
