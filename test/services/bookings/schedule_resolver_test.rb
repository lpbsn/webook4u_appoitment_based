require "test_helper"

class Bookings::ScheduleResolverTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Salon resolver", slug: "salon-resolver")
    @enseigne = @client.enseignes.create!(name: "Enseigne resolver")
  end

  test "returns enseigne opening hours when they exist for the day" do
    create_weekday_opening_hours_for_enseigne(@enseigne, opens_at: "10:00", closes_at: "16:00")

    intervals = Bookings::ScheduleResolver.new(
      client: @client,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [ [ Time.zone.local(2026, 3, 16, 10, 0, 0), Time.zone.local(2026, 3, 16, 16, 0, 0) ] ], intervals
  end

  test "returns empty when enseigne has opening hours on another day only" do
    @enseigne.enseigne_opening_hours.create!(day_of_week: 2, opens_at: "09:00", closes_at: "18:00")

    intervals = Bookings::ScheduleResolver.new(
      client: @client,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [], intervals
  end

  test "returns empty when neither client nor enseigne have opening hours for the day" do
    intervals = Bookings::ScheduleResolver.new(
      client: @client,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 22)
    ).call

    assert_equal [], intervals
  end

  test "uses opening hours from the selected enseigne only" do
    other_enseigne = @client.enseignes.create!(name: "Other enseigne")
    other_enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "08:00", closes_at: "12:00")
    other_enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "13:00", closes_at: "20:00")
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "10:00", closes_at: "16:00")

    intervals = Bookings::ScheduleResolver.new(
      client: @client,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [ [ Time.zone.local(2026, 3, 16, 10, 0, 0), Time.zone.local(2026, 3, 16, 16, 0, 0) ] ], intervals
  end

  test "returns multiple disjoint intervals ordered for enseigne opening hours" do
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "14:00", closes_at: "18:00")

    intervals = Bookings::ScheduleResolver.new(
      client: @client,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [
      [ Time.zone.local(2026, 3, 16, 9, 0, 0), Time.zone.local(2026, 3, 16, 12, 0, 0) ],
      [ Time.zone.local(2026, 3, 16, 14, 0, 0), Time.zone.local(2026, 3, 16, 18, 0, 0) ]
    ], intervals
  end
end
