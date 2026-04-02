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
      Bookings::PublicPage.new(slug: "unknown-xyz", enseigne_id: nil, service_id: nil, date_param: nil).call
    end
  end

  test "returns client and services for known slug without selection" do
    result = Bookings::PublicPage.new(slug: @client.slug, enseigne_id: nil, service_id: nil, date_param: nil).call

    assert_equal @client, result.client
    assert_equal [ @enseigne ], result.enseignes.to_a
    assert_equal @enseigne, result.selected_enseigne
    assert_includes result.services, @service
    assert_nil result.selected_service
    assert_nil result.date
    assert_equal [], result.slots
  end

  test "returns no slots when service is selected but date is absent" do
    result = Bookings::PublicPage.new(
      slug: @client.slug,
      enseigne_id: @enseigne.id.to_s,
      service_id: @service.id.to_s,
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
      date_param: "2026-03-16"
    ).call

    assert_equal @enseigne, result.selected_enseigne
    assert_nil result.selected_service
    assert_equal [ @service ], result.services.to_a
  end
end
