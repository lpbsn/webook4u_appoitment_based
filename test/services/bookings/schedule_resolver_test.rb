require "test_helper"

class Bookings::ScheduleResolverTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Salon resolver", slug: "salon-resolver")
    @enseigne = @client.enseignes.create!(name: "Enseigne resolver")
  end

  test "returns enseigne opening hours when they exist for the day" do
    create_weekday_opening_hours_for(@client, opens_at: "09:00", closes_at: "18:00")
    create_weekday_opening_hours_for_enseigne(@enseigne, opens_at: "10:00", closes_at: "16:00")

    intervals = Bookings::ScheduleResolver.new(
      client: @client,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [ [ Time.zone.local(2026, 3, 16, 10, 0, 0), Time.zone.local(2026, 3, 16, 16, 0, 0) ] ], intervals
  end

  test "falls back to client opening hours when enseigne has none for the day" do
    create_weekday_opening_hours_for(@client, opens_at: "09:00", closes_at: "18:00")

    intervals = Bookings::ScheduleResolver.new(
      client: @client,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [ [ Time.zone.local(2026, 3, 16, 9, 0, 0), Time.zone.local(2026, 3, 16, 18, 0, 0) ] ], intervals
  end

  test "returns empty when neither client nor enseigne have opening hours for the day" do
    intervals = Bookings::ScheduleResolver.new(
      client: @client,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 22)
    ).call

    assert_equal [], intervals
  end

  test "enseigne hours mask all client hours for the same day" do
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "14:00", closes_at: "18:00")
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "10:00", closes_at: "16:00")

    intervals = Bookings::ScheduleResolver.new(
      client: @client,
      enseigne: @enseigne,
      date: Date.new(2026, 3, 16)
    ).call

    assert_equal [ [ Time.zone.local(2026, 3, 16, 10, 0, 0), Time.zone.local(2026, 3, 16, 16, 0, 0) ] ], intervals
  end

  test "returns multiple disjoint intervals ordered for the selected source" do
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "14:00", closes_at: "18:00")

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
