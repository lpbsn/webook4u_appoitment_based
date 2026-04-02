# Unit tests for Bookings::Input (date/time sanitization for booking flow).
# Secures refactor 2.1: max_future_days and boundaries must stay consistent with BookingRules.

require "test_helper"

class Bookings::InputTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  # --- safe_date ---

  test "safe_date returns nil for blank" do
    assert_nil Bookings::Input.safe_date("")
    assert_nil Bookings::Input.safe_date(nil)
  end

  test "safe_date returns parsed date for valid ISO date" do
    travel_to Date.new(2026, 3, 15).to_time do
      assert_equal Date.new(2026, 3, 20), Bookings::Input.safe_date("2026-03-20")
    end
  end

  test "safe_date returns nil for past date" do
    travel_to Time.zone.local(2026, 3, 15, 12, 0, 0) do
      assert_nil Bookings::Input.safe_date("2026-03-14")
    end
  end

  # UTC 23:01 = Paris 00:01 on Mar 16: server UTC date is still Mar 15
  # but business_today is already Mar 16 — Mar 15 must be rejected.
  test "safe_date rejects the Paris-previous-day when UTC server date still shows that day" do
    travel_to Time.utc(2026, 3, 15, 23, 1, 0) do
      assert_nil Bookings::Input.safe_date("2026-03-15")
    end
  end

  test "safe_date accepts the Paris-today even when UTC date is still the previous day" do
    travel_to Time.utc(2026, 3, 15, 23, 1, 0) do
      assert_equal Date.new(2026, 3, 16), Bookings::Input.safe_date("2026-03-16")
    end
  end

  test "safe_date returns nil for date beyond max_future_days" do
    travel_to Time.zone.local(2026, 3, 15, 12, 0, 0) do
      # Within 30 days: accept
      assert_equal Date.new(2026, 4, 10), Bookings::Input.safe_date("2026-04-10")
      # Beyond 30 days: reject
      assert_nil Bookings::Input.safe_date("2026-04-16")
    end
  end

  test "safe_date returns nil for invalid format" do
    assert_nil Bookings::Input.safe_date("not-a-date")
    assert_nil Bookings::Input.safe_date("2026/03/20")
  end

  test "safe_date accepts today" do
    travel_to Time.zone.local(2026, 3, 15, 12, 0, 0) do
      assert_equal Date.new(2026, 3, 15), Bookings::Input.safe_date("2026-03-15")
    end
  end

  # --- safe_time ---

  test "safe_time returns nil for blank" do
    assert_nil Bookings::Input.safe_time("")
    assert_nil Bookings::Input.safe_time(nil)
  end

  test "safe_time returns parsed time for valid time in range" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      parsed = Bookings::Input.safe_time("2026-03-20 10:00:00")
      assert_not_nil parsed
      assert_equal Time.zone.local(2026, 3, 20, 10, 0, 0), parsed
    end
  end

  test "safe_time returns nil for past time" do
    travel_to Time.zone.local(2026, 3, 15, 12, 0, 0) do
      assert_nil Bookings::Input.safe_time("2026-03-15 11:00:00")
    end
  end

  test "safe_time returns nil for time beyond max_future_days" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      # 31 days ahead
      assert_nil Bookings::Input.safe_time("2026-04-16 10:00:00")
    end
  end

  test "safe_time returns nil for invalid format" do
    assert_nil Bookings::Input.safe_time("bonjour")
  end
end
