# frozen_string_literal: true

require "test_helper"

class Bookings::PublicPageTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(name: "Salon Page", slug: "salon-page")
    @enseigne = @client.enseignes.create!(name: "Enseigne A", full_address: "1 rue de Paris", active: true)
    @service = @enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)
    staff = @enseigne.staffs.create!(name: "Staff page", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: @service)
    create_weekday_opening_hours_for_enseigne(@enseigne)
  end

  test "raises RecordNotFound for unknown slug" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Bookings::PublicPage.new(
        slug: "unknown-xyz",
        enseigne_id: nil,
        service_id: nil,
        assignment_mode_param: nil,
        staff_id_param: nil,
        date_param: nil
      ).call
    end
  end

  test "returns client and services for known slug without selection" do
    result = Bookings::PublicPage.new(
      slug: @client.slug,
      enseigne_id: @enseigne.id.to_s,
      service_id: @service.id.to_s,
      assignment_mode_param: nil,
      staff_id_param: nil,
      date_param: nil
    ).call

    assert_equal @client, result.client
    assert_equal [ @enseigne ], result.enseignes.to_a
    assert_equal @enseigne, result.selected_enseigne
    assert_includes result.services, @service
    assert_equal @service, result.selected_service
    assert_nil result.date
    assert_equal [], result.slots
  end

  test "returns no slots when service is selected but date is absent" do
    result = Bookings::PublicPage.new(
      slug: @client.slug,
      enseigne_id: @enseigne.id.to_s,
      service_id: @service.id.to_s,
      assignment_mode_param: nil,
      staff_id_param: nil,
      date_param: nil
    ).call

    assert_equal @enseigne, result.selected_enseigne
    assert_equal @service, result.selected_service
    assert_nil result.date
    assert_equal [], result.slots
  end

  test "returns no slots when service is absent but date is present" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      result = Bookings::PublicPage.new(
        slug: @client.slug,
        enseigne_id: @enseigne.id.to_s,
        service_id: nil,
        assignment_mode_param: nil,
        staff_id_param: nil,
        date_param: "2026-03-16"
      ).call

      assert_equal @enseigne, result.selected_enseigne
      assert_nil result.selected_service
      assert_equal [], result.slots
    end
  end

  test "returns slots when service and valid date are provided" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      result = Bookings::PublicPage.new(
        slug: @client.slug,
        enseigne_id: @enseigne.id.to_s,
        service_id: @service.id.to_s,
        assignment_mode_param: nil,
        staff_id_param: nil,
        date_param: "2026-03-16"
      ).call

      assert_equal @enseigne, result.selected_enseigne
      assert_equal @service, result.selected_service
      assert_equal Date.new(2026, 3, 16), result.date
      assert result.slots.any?, "Expected available slots for a free Monday"
    end
  end

  test "returns empty slots when selected service has no eligible active staff" do
    service_without_capability = @enseigne.services.create!(
      name: "Brushing",
      duration_minutes: 30,
      price_cents: 3000
    )

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      result = Bookings::PublicPage.new(
        slug: @client.slug,
        enseigne_id: @enseigne.id.to_s,
        service_id: service_without_capability.id.to_s,
        assignment_mode_param: nil,
        staff_id_param: nil,
        date_param: "2026-03-16"
      ).call

      assert_equal service_without_capability, result.selected_service
      assert_equal [], result.slots
    end
  end

  test "returns empty slots when date is beyond max_future_days" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      date_beyond = (Date.current + (BookingRules.max_future_days + 1).days).iso8601

      result = Bookings::PublicPage.new(
        slug: @client.slug,
        enseigne_id: @enseigne.id.to_s,
        service_id: @service.id.to_s,
        assignment_mode_param: nil,
        staff_id_param: nil,
        date_param: date_beyond
      ).call

      assert_equal @enseigne, result.selected_enseigne
      assert_nil result.date
      assert_equal [], result.slots
    end
  end

  test "returns no selected enseigne when several active enseignes exist and none is chosen" do
    @client.enseignes.create!(name: "Enseigne B", full_address: "2 rue de Paris", active: true)

    result = Bookings::PublicPage.new(
      slug: @client.slug,
      enseigne_id: nil,
      service_id: @service.id.to_s,
      assignment_mode_param: nil,
      staff_id_param: nil,
      date_param: "2026-03-16"
    ).call

    assert_nil result.selected_enseigne
    assert_nil result.selected_service
    assert_equal [], result.slots
  end

  test "does not expose inactive enseignes" do
    inactive_enseigne = @client.enseignes.create!(name: "Inactive", full_address: "3 rue de Paris", active: false)

    result = Bookings::PublicPage.new(
      slug: @client.slug,
      enseigne_id: inactive_enseigne.id,
      service_id: nil,
      assignment_mode_param: nil,
      staff_id_param: nil,
      date_param: nil
    ).call

    assert_equal [ @enseigne ], result.enseignes.to_a
    assert_nil result.selected_enseigne
  end

  test "returns no selected enseigne when client has no active enseigne" do
    @enseigne.update!(active: false)

    result = Bookings::PublicPage.new(
      slug: @client.slug,
      enseigne_id: nil,
      service_id: nil,
      assignment_mode_param: nil,
      staff_id_param: nil,
      date_param: nil
    ).call

    assert_equal [], result.enseignes.to_a
    assert_nil result.selected_enseigne
    assert_equal [], result.slots
  end

  test "ignores service_id that does not belong to selected enseigne" do
    other_enseigne = @client.enseignes.create!(name: "Enseigne B", full_address: "2 rue de Paris", active: true)
    other_service = other_enseigne.services.create!(name: "Coloration", duration_minutes: 45, price_cents: 5000)

    result = Bookings::PublicPage.new(
      slug: @client.slug,
      enseigne_id: @enseigne.id.to_s,
      service_id: other_service.id.to_s,
      assignment_mode_param: nil,
      staff_id_param: nil,
      date_param: "2026-03-16"
    ).call

    assert_equal @enseigne, result.selected_enseigne
    assert_nil result.selected_service
    assert_equal [ @service ], result.services.to_a
  end

  test "call keeps search_mode nil when param is absent" do
    client = Client.create!(name: "Salon Search", slug: "salon-search")
    enseigne = client.enseignes.create!(name: "Enseigne Search", full_address: "1 rue search", active: true)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    result = Bookings::PublicPage.new(
      slug: client.slug,
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode_param: "automatic",
      staff_id_param: nil,
      search_mode_param: nil,
      selected_start_time_param: nil,
      date_param: nil
    ).call

    assert_nil result.search_mode
    assert_nil result.selected_start_time
  end

  test "call exposes valid search_mode from params" do
    client = Client.create!(name: "Salon Search Mode", slug: "salon-search-mode")
    enseigne = client.enseignes.create!(name: "Enseigne Search Mode", full_address: "1 rue mode", active: true)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    result = Bookings::PublicPage.new(
      slug: client.slug,
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode_param: "automatic",
      staff_id_param: nil,
      search_mode_param: "precise_date",
      selected_start_time_param: nil,
      date_param: nil
    ).call

    assert_equal "precise_date", result.search_mode
  end

  test "call exposes selected_start_time as provided" do
    client = Client.create!(name: "Salon Selected Slot", slug: "salon-selected-slot")
    enseigne = client.enseignes.create!(name: "Enseigne Selected Slot", full_address: "1 rue slot", active: true)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    selected_start_time = "2026-03-16 10:00"

    assert_no_difference "Booking.count" do
      result = Bookings::PublicPage.new(
        slug: client.slug,
        enseigne_id: enseigne.id,
        service_id: service.id,
        assignment_mode_param: "automatic",
        staff_id_param: nil,
        search_mode_param: nil,
        selected_start_time_param: selected_start_time,
        date_param: nil
      ).call

      assert_equal selected_start_time, result.selected_start_time
    end
  end

  test "call keeps search_mode nil when assignment mode is not resolved" do
    client = Client.create!(name: "Salon Incomplete", slug: "salon-incomplete")
    enseigne = client.enseignes.create!(name: "Enseigne Incomplete", full_address: "1 rue incomplete", active: true)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    result = Bookings::PublicPage.new(
      slug: client.slug,
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode_param: nil,
      staff_id_param: nil,
      search_mode_param: "precise_date",
      selected_start_time_param: nil,
      date_param: nil
    ).call

    assert_nil result.assignment_mode
    assert_nil result.search_mode
  end

  test "returns first available criteria state when search mode is first_available" do
    client = Client.create!(name: "Salon", slug: "salon")
    enseigne = client.enseignes.create!(name: "Enseigne", active: true)
    enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")

    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    result = Bookings::PublicPage.new(
      slug: client.slug,
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode_param: "automatic",
      staff_id_param: nil,
      search_mode_param: "first_available",
      selected_start_time_param: nil,
      date_param: nil,
      first_available_selected_days_of_week_param: [ "1" ],
      first_available_start_time_min_param: "09:00",
      first_available_start_time_max_param: "18:00"
    ).call

    assert_equal [ 1 ], result.first_available_selected_days_of_week
    assert_equal "09:00", result.first_available_start_time_min
    assert_equal "18:00", result.first_available_start_time_max
    assert_equal [ 1 ], result.first_available_available_days_of_week
    assert_equal({}, result.first_available_errors)
  end

  test "returns validation errors for incomplete first available criteria" do
    client = Client.create!(name: "Salon", slug: "salon-errors")
    enseigne = client.enseignes.create!(name: "Enseigne", active: true)
    enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")

    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    result = Bookings::PublicPage.new(
      slug: client.slug,
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode_param: "automatic",
      staff_id_param: nil,
      search_mode_param: "first_available",
      selected_start_time_param: nil,
      date_param: nil,
      first_available_selected_days_of_week_param: [],
      first_available_start_time_min_param: nil,
      first_available_start_time_max_param: "18:00"
    ).call

    assert_equal "Sélectionnez au moins un jour.", result.first_available_errors[:selected_days_of_week]
    assert_equal "L'heure de début minimale est obligatoire.", result.first_available_errors[:start_time_min]
  end

  test "does not add first available validation errors when search mode is precise_date" do
    client = Client.create!(name: "Salon", slug: "salon-precise-page")
    enseigne = client.enseignes.create!(name: "Enseigne", active: true)
    enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")

    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    result = Bookings::PublicPage.new(
      slug: client.slug,
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode_param: "automatic",
      staff_id_param: nil,
      search_mode_param: "precise_date",
      selected_start_time_param: nil,
      date_param: nil,
      first_available_selected_days_of_week_param: [],
      first_available_start_time_min_param: nil,
      first_available_start_time_max_param: nil
    ).call

    assert_equal({}, result.first_available_errors)
  end
end
