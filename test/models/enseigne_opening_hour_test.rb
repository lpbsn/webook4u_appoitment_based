require "test_helper"

class EnseigneOpeningHourTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Salon enseigne", slug: "salon-enseigne-horaires")
    @enseigne = @client.enseignes.create!(name: "Enseigne A")
    @other_enseigne = @client.enseignes.create!(name: "Enseigne B")
  end

  test "valid opening hour saves without errors" do
    opening_hour = EnseigneOpeningHour.new(
      enseigne: @enseigne,
      day_of_week: 1,
      opens_at: "10:00",
      closes_at: "16:00"
    )

    assert opening_hour.valid?
  end

  test "day_of_week is required" do
    opening_hour = EnseigneOpeningHour.new(enseigne: @enseigne, opens_at: "10:00", closes_at: "16:00")

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:day_of_week], "can't be blank"
  end

  test "opens_at is required" do
    opening_hour = EnseigneOpeningHour.new(enseigne: @enseigne, day_of_week: 1, closes_at: "16:00")

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:opens_at], "can't be blank"
  end

  test "closes_at is required" do
    opening_hour = EnseigneOpeningHour.new(enseigne: @enseigne, day_of_week: 1, opens_at: "10:00")

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:closes_at], "can't be blank"
  end

  test "opens_at must be before closes_at" do
    opening_hour = EnseigneOpeningHour.new(
      enseigne: @enseigne,
      day_of_week: 1,
      opens_at: "16:00",
      closes_at: "10:00"
    )

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:opens_at], "must be before closes_at"
  end

  test "rejects exact duplicate for same enseigne and day" do
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "10:00", closes_at: "16:00")

    opening_hour = EnseigneOpeningHour.new(
      enseigne: @enseigne,
      day_of_week: 1,
      opens_at: "10:00",
      closes_at: "16:00"
    )

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:opens_at], "duplicates an existing opening hour for this day"
  end

  test "rejects overlapping interval for same enseigne and day" do
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "10:00", closes_at: "16:00")

    opening_hour = EnseigneOpeningHour.new(
      enseigne: @enseigne,
      day_of_week: 1,
      opens_at: "15:00",
      closes_at: "18:00"
    )

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:opens_at], "overlaps an existing opening hour for this day"
  end

  test "rejects contained interval for same enseigne and day" do
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")

    opening_hour = EnseigneOpeningHour.new(
      enseigne: @enseigne,
      day_of_week: 1,
      opens_at: "11:00",
      closes_at: "12:00"
    )

    assert_not opening_hour.valid?
    assert_includes opening_hour.errors[:opens_at], "overlaps an existing opening hour for this day"
  end

  test "allows disjoint intervals for same enseigne and day" do
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "10:00", closes_at: "12:00")

    opening_hour = EnseigneOpeningHour.new(
      enseigne: @enseigne,
      day_of_week: 1,
      opens_at: "14:00",
      closes_at: "18:00"
    )

    assert opening_hour.valid?
  end

  test "allows contiguous intervals for same enseigne and day" do
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "10:00", closes_at: "12:00")

    opening_hour = EnseigneOpeningHour.new(
      enseigne: @enseigne,
      day_of_week: 1,
      opens_at: "12:00",
      closes_at: "16:00"
    )

    assert opening_hour.valid?
  end

  test "allows same interval on another day" do
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "10:00", closes_at: "16:00")

    opening_hour = EnseigneOpeningHour.new(
      enseigne: @enseigne,
      day_of_week: 2,
      opens_at: "10:00",
      closes_at: "16:00"
    )

    assert opening_hour.valid?
  end

  test "allows same interval on another enseigne" do
    @enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "10:00", closes_at: "16:00")

    opening_hour = EnseigneOpeningHour.new(
      enseigne: @other_enseigne,
      day_of_week: 1,
      opens_at: "10:00",
      closes_at: "16:00"
    )

    assert opening_hour.valid?
  end
end
