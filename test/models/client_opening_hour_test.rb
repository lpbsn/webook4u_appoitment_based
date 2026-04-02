require "test_helper"

class ClientOpeningHourTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Salon horaires", slug: "salon-horaires")
    @other_client = Client.create!(name: "Salon horaires bis", slug: "salon-horaires-bis")
  end

  test "valid opening hour saves without errors" do
    opening_hour = ClientOpeningHour.new(
      client: @client,
      day_of_week: 1,
      opens_at: "09:00",
      closes_at: "18:00"
    )

    assert opening_hour.valid?
  end

  test "day_of_week is required" do
    opening_hour = ClientOpeningHour.new(client: @client, opens_at: "09:00", closes_at: "18:00")

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:day_of_week], "can't be blank"
  end

  test "opens_at is required" do
    opening_hour = ClientOpeningHour.new(client: @client, day_of_week: 1, closes_at: "18:00")

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:opens_at], "can't be blank"
  end

  test "closes_at is required" do
    opening_hour = ClientOpeningHour.new(client: @client, day_of_week: 1, opens_at: "09:00")

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:closes_at], "can't be blank"
  end

  test "opens_at must be before closes_at" do
    opening_hour = ClientOpeningHour.new(
      client: @client,
      day_of_week: 1,
      opens_at: "18:00",
      closes_at: "09:00"
    )

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:opens_at], "must be before closes_at"
  end

  test "rejects exact duplicate for same client and day" do
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")

    opening_hour = ClientOpeningHour.new(
      client: @client,
      day_of_week: 1,
      opens_at: "09:00",
      closes_at: "12:00"
    )

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:opens_at], "duplicates an existing opening hour for this day"
  end

  test "rejects overlapping interval for same client and day" do
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")

    opening_hour = ClientOpeningHour.new(
      client: @client,
      day_of_week: 1,
      opens_at: "11:00",
      closes_at: "13:00"
    )

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:opens_at], "overlaps an existing opening hour for this day"
  end

  test "rejects contained interval for same client and day" do
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "15:00")

    opening_hour = ClientOpeningHour.new(
      client: @client,
      day_of_week: 1,
      opens_at: "10:00",
      closes_at: "12:00"
    )

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:opens_at], "overlaps an existing opening hour for this day"
  end

  test "allows disjoint intervals for same client and day" do
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")

    opening_hour = ClientOpeningHour.new(
      client: @client,
      day_of_week: 1,
      opens_at: "14:00",
      closes_at: "18:00"
    )

    assert opening_hour.valid?
  end

  test "allows contiguous intervals for same client and day" do
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")

    opening_hour = ClientOpeningHour.new(
      client: @client,
      day_of_week: 1,
      opens_at: "12:00",
      closes_at: "18:00"
    )

    assert opening_hour.valid?
  end

  test "allows same interval on another day" do
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")

    opening_hour = ClientOpeningHour.new(
      client: @client,
      day_of_week: 2,
      opens_at: "09:00",
      closes_at: "12:00"
    )

    assert opening_hour.valid?
  end

  test "allows same interval on another client" do
    @client.client_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")

    opening_hour = ClientOpeningHour.new(
      client: @other_client,
      day_of_week: 1,
      opens_at: "09:00",
      closes_at: "12:00"
    )

    assert opening_hour.valid?
  end
end
