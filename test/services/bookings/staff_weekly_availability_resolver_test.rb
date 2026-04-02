require "test_helper"

class Bookings::StaffWeeklyAvailabilityResolverTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client weekly", slug: "client-weekly")
    @enseigne = @client.enseignes.create!(name: "Enseigne weekly")
    @staff = @enseigne.staffs.create!(name: "Staff weekly", active: true)
  end

  test "returns ordered weekly windows for the requested day" do
    @staff.staff_availabilities.create!(day_of_week: 1, opens_at: "14:00", closes_at: "18:00")
    @staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    @staff.staff_availabilities.create!(day_of_week: 2, opens_at: "10:00", closes_at: "16:00")

    windows = Bookings::StaffWeeklyAvailabilityResolver.new(
      staff: @staff,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [
      [ Time.zone.local(2026, 3, 16, 9, 0, 0), Time.zone.local(2026, 3, 16, 12, 0, 0) ],
      [ Time.zone.local(2026, 3, 16, 14, 0, 0), Time.zone.local(2026, 3, 16, 18, 0, 0) ]
    ], windows
  end

  test "returns no window when staff has no exploitable availability for the day" do
    @staff.staff_availabilities.create!(day_of_week: 2, opens_at: "10:00", closes_at: "16:00")

    windows = Bookings::StaffWeeklyAvailabilityResolver.new(
      staff: @staff,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [], windows
  end

  test "does not rely on ScheduleResolver" do
    @staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")

    schedule_resolver_singleton = class << Bookings::ScheduleResolver; self; end
    schedule_resolver_singleton.alias_method :new_without_staff_weekly_resolver_test, :new
    schedule_resolver_singleton.define_method(:new) do |*_args, **_kwargs|
      raise "ScheduleResolver should not be called by StaffWeeklyAvailabilityResolver"
    end

    begin
      windows = Bookings::StaffWeeklyAvailabilityResolver.new(
        staff: @staff,
        date: Date.new(2026, 3, 16)
      ).call

      assert_equal [ [ Time.zone.local(2026, 3, 16, 9, 0, 0), Time.zone.local(2026, 3, 16, 12, 0, 0) ] ], windows
    ensure
      schedule_resolver_singleton.alias_method :new, :new_without_staff_weekly_resolver_test
      schedule_resolver_singleton.remove_method :new_without_staff_weekly_resolver_test
    end
  end
end
