require "test_helper"

class Bookings::StaffUnavailabilitySubtractorTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client unavailability", slug: "client-unavailability")
    @enseigne = @client.enseignes.create!(name: "Enseigne unavailability")
    @staff = @enseigne.staffs.create!(name: "Staff unavailability", active: true)

    @staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
  end

  test "partial unavailability truncates weekly window" do
    @staff.staff_unavailabilities.create!(
      starts_at: Time.zone.local(2026, 3, 16, 12, 0, 0),
      ends_at: Time.zone.local(2026, 3, 16, 14, 0, 0)
    )

    weekly_windows = Bookings::StaffWeeklyAvailabilityResolver.new(
      staff: @staff,
      date: Date.new(2026, 3, 16)
    ).call

    windows = Bookings::StaffUnavailabilitySubtractor.new(
      staff: @staff,
      date: Date.new(2026, 3, 16),
      windows: weekly_windows
    ).call

    assert_equal [
      [ Time.zone.local(2026, 3, 16, 9, 0, 0), Time.zone.local(2026, 3, 16, 12, 0, 0) ],
      [ Time.zone.local(2026, 3, 16, 14, 0, 0), Time.zone.local(2026, 3, 16, 18, 0, 0) ]
    ], windows
  end

  test "full-day overlap removes exploitable window" do
    @staff.staff_unavailabilities.create!(
      starts_at: Time.zone.local(2026, 3, 16, 8, 0, 0),
      ends_at: Time.zone.local(2026, 3, 16, 19, 0, 0)
    )

    weekly_windows = Bookings::StaffWeeklyAvailabilityResolver.new(
      staff: @staff,
      date: Date.new(2026, 3, 16)
    ).call

    windows = Bookings::StaffUnavailabilitySubtractor.new(
      staff: @staff,
      date: Date.new(2026, 3, 16),
      windows: weekly_windows
    ).call

    assert_equal [], windows
  end
end
