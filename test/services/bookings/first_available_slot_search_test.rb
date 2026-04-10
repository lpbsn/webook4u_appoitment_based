require "test_helper"

class Bookings::FirstAvailableSlotSearchTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(
      name: "Salon search",
      slug: "salon-search"
    )

    @enseigne = @client.enseignes.create!(
      name: "Enseigne principale"
    )

    @service = @enseigne.services.create!(
      name: "Coupe",
      duration_minutes: 30,
      price_cents: 2500
    )

    @staff_1 = @enseigne.staffs.create!(name: "Alice", active: true)
    @staff_2 = @enseigne.staffs.create!(name: "Bob", active: true)

    @staff_1.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    @staff_2.staff_availabilities.create!(day_of_week: 2, opens_at: "10:00", closes_at: "13:00")

    StaffServiceCapability.create!(staff: @staff_1, service: @service)
    StaffServiceCapability.create!(staff: @staff_2, service: @service)

    create_weekday_opening_hours_for_enseigne(@enseigne)
  end

  test "returns first chronological slot in automatic mode" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Bookings::FirstAvailableSlotSearch.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        assignment_mode: "automatic",
        staff: nil,
        selected_days_of_week: [ 1, 2 ],
        start_time_min: "09:00",
        start_time_max: "18:00"
      ).call

      assert_equal Time.zone.local(2026, 3, 16, 9, 0, 0), slot
    end
  end

  test "respects selected_days_of_week" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Bookings::FirstAvailableSlotSearch.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        assignment_mode: "automatic",
        staff: nil,
        selected_days_of_week: [ 2 ],
        start_time_min: "09:00",
        start_time_max: "18:00"
      ).call

      assert_equal Time.zone.local(2026, 3, 17, 10, 0, 0), slot
    end
  end

  test "respects start_time_min" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Bookings::FirstAvailableSlotSearch.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        assignment_mode: "automatic",
        staff: nil,
        selected_days_of_week: [ 1 ],
        start_time_min: "10:30",
        start_time_max: "18:00"
      ).call

      assert_equal Time.zone.local(2026, 3, 16, 10, 30, 0), slot
    end
  end

  test "respects start_time_max" do
    @staff_1.staff_availabilities.delete_all
    @staff_1.staff_availabilities.create!(day_of_week: 1, opens_at: "14:00", closes_at: "18:00")

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Bookings::FirstAvailableSlotSearch.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        assignment_mode: "automatic",
        staff: nil,
        selected_days_of_week: [ 1 ],
        start_time_min: "09:00",
        start_time_max: "13:00"
      ).call

      assert_nil slot
    end
  end

  test "supports specific_staff mode" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Bookings::FirstAvailableSlotSearch.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        assignment_mode: "specific_staff",
        staff: @staff_2,
        selected_days_of_week: [ 1, 2 ],
        start_time_min: "09:00",
        start_time_max: "18:00"
      ).call

      assert_equal Time.zone.local(2026, 3, 17, 10, 0, 0), slot
    end
  end

  test "returns nil in specific_staff mode when staff is missing" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Bookings::FirstAvailableSlotSearch.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        assignment_mode: "specific_staff",
        staff: nil,
        selected_days_of_week: [ 1, 2 ],
        start_time_min: "09:00",
        start_time_max: "18:00"
      ).call

      assert_nil slot
    end
  end
  test "returns nil when no slot matches selected days and time range" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Bookings::FirstAvailableSlotSearch.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        assignment_mode: "automatic",
        staff: nil,
        selected_days_of_week: [ 3 ],
        start_time_min: "15:00",
        start_time_max: "16:00"
      ).call

      assert_nil slot
    end
  end

  test "starts search from BookingRules.minimum_bookable_time" do
    @staff_1.staff_availabilities.delete_all
    @staff_1.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    @staff_2.staff_availabilities.delete_all

    travel_to Time.zone.local(2026, 3, 16, 9, 50, 0) do
      slot = Bookings::FirstAvailableSlotSearch.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        assignment_mode: "automatic",
        staff: nil,
        selected_days_of_week: [ 1 ],
        start_time_min: "09:00",
        start_time_max: "18:00"
      ).call

      assert_equal Time.zone.local(2026, 3, 16, 10, 30, 0), slot
    end
  end
end
