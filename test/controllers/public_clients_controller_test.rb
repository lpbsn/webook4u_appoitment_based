require "test_helper"

class PublicClientsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "GET show returns success for valid client slug" do
    client = Client.create!(name: "Salon", slug: "salon")
    client.enseignes.create!(name: "Enseigne active", full_address: "1 rue de Paris", active: true)
    get public_client_url(client.slug)
    assert_response :success
  end

  test "GET show returns 404 for unknown client slug" do
    get public_client_url("slug-inexistant-xyz")
    assert_response :not_found
  end

  test "date input has min set to today to prevent past date selection" do
    client = Client.create!(name: "Salon Min", slug: "salon-min")
    enseigne = client.enseignes.create!(name: "Enseigne Min", full_address: "1 rue min", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      get public_client_url(client.slug), params: { enseigne_id: enseigne.id, service_id: service.id }
      assert_response :success
      assert_select 'input[name="enseigne_id"][value=?]', enseigne.id.to_s
      assert_select 'input[name="date"][min=?]', Date.current.iso8601
    end
  end

  # We assert no start_time input (slot choice) instead of recap copy ("Date :", "—") so the test is stable if labels change.
  # When date is beyond max_future_days, safe_date is nil so the slots step is not rendered.
  test "rejects date beyond max_future_days and does not show slots" do
    client = Client.create!(name: "Salon", slug: "salon")
    enseigne = client.enseignes.create!(name: "Enseigne active", full_address: "1 rue de Paris", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      date_beyond = (Date.current + (BookingRules.max_future_days + 1).days).iso8601
      get public_client_url(client.slug), params: { enseigne_id: enseigne.id, service_id: service.id, date: date_beyond }
      assert_response :success
      assert_select 'input[name="start_time"]', count: 0
    end
  end

  test "show lists only active enseignes" do
    client = Client.create!(name: "Salon Enseignes", slug: "salon-enseignes")
    active_enseigne = client.enseignes.create!(name: "Enseigne active", full_address: "1 rue active", active: true)
    client.enseignes.create!(name: "Enseigne inactive", full_address: "2 rue inactive", active: false)

    get public_client_url(client.slug)

    assert_response :success
    assert_includes response.body, active_enseigne.name
    assert_includes response.body, active_enseigne.full_address
    assert_not_includes response.body, "Enseigne inactive"
  end

  test "show does not render service step when several active enseignes exist without selection" do
    client = Client.create!(name: "Salon Multi", slug: "salon-multi")
    enseigne_a = client.enseignes.create!(name: "Enseigne A", full_address: "1 rue A", active: true)
    client.enseignes.create!(name: "Enseigne B", full_address: "2 rue B", active: true)
    enseigne_a.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    get public_client_url(client.slug)

    assert_response :success
    assert_select "h2", text: "1. Choisissez une enseigne"
    assert_select "h2", text: "2. Choisissez une prestation", count: 0
  end

  test "show displays unavailable tunnel message when no active enseigne exists" do
    client = Client.create!(name: "Salon Vide", slug: "salon-vide")
    client.enseignes.create!(name: "Inactive", full_address: "3 rue vide", active: false)

    get public_client_url(client.slug)

    assert_response :success
    assert_includes response.body, "Aucune enseigne active n'est disponible pour le moment."
  end

  test "show auto-selects the single active enseigne and keeps the flow usable" do
    client = Client.create!(name: "Salon Single", slug: "salon-single")
    enseigne = client.enseignes.create!(name: "Enseigne unique", full_address: "1 rue unique", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    get public_client_url(client.slug), params: { service_id: service.id }

    assert_response :success
    assert_includes response.body, enseigne.name
    assert_select "h2", text: "2. Choisissez une prestation"
    assert_select "input[name=\"enseigne_id\"][value=?]", enseigne.id.to_s
  end
end
