require "test_helper"

class Bookings::StaffVisibleWindowsResolverTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client visible windows", slug: "client-visible-windows")
    @enseigne = @client.enseignes.create!(name: "Enseigne visible windows")
    @staff = @enseigne.staffs.create!(name: "Staff visible windows", active: true)
    @service = @enseigne.services.create!(name: "Service visible windows", duration_minutes: 30, price_cents: 2500)
  end

  test "returns empty when enseigne has no opening hours for the day" do
    @staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")

    windows = Bookings::StaffVisibleWindowsResolver.new(
      staff: @staff,
      service: @service,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [], windows
  end

  test "intersects enseigne opening hours with staff real availability windows" do
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    @staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "16:00")
    @staff.staff_unavailabilities.create!(
      starts_at: Time.zone.local(2026, 3, 16, 12, 0, 0),
      ends_at: Time.zone.local(2026, 3, 16, 13, 0, 0)
    )

    windows = Bookings::StaffVisibleWindowsResolver.new(
      staff: @staff,
      service: @service,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [
      [ Time.zone.local(2026, 3, 16, 10, 0, 0), Time.zone.local(2026, 3, 16, 12, 0, 0) ],
      [ Time.zone.local(2026, 3, 16, 13, 0, 0), Time.zone.local(2026, 3, 16, 16, 0, 0) ]
    ], windows
  end

  test "drops windows shorter than service duration" do
    long_service = @enseigne.services.create!(name: "Long service", duration_minutes: 90, price_cents: 5000)
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "10:00", closes_at: "11:00")
    @staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "11:00")

    windows = Bookings::StaffVisibleWindowsResolver.new(
      staff: @staff,
      service: long_service,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [], windows
  end
end
