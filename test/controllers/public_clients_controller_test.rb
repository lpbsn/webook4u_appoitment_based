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

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      get public_client_url(client.slug), params: {
        enseigne_id: enseigne.id,
        service_id: service.id,
        assignment_mode: "automatic",
        search_mode: "precise_date"
      }

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
    assert_select "h2", text: "1. Choisir une enseigne"
    assert_select "h2", text: "2. Choisir un service", count: 0
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

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      service_id: service.id,
      assignment_mode: "automatic"
    }

    assert_response :success
    assert_includes response.body, enseigne.name
    assert_includes response.body, "2. Choisir un service"
    assert_select 'input[name="enseigne_id"][value=?]', enseigne.id.to_s
  end

  test "show renders automatic staff option as Tous while keeping automatic assignment_mode" do
    client = Client.create!(name: "Salon Tous", slug: "salon-tous")
    enseigne = client.enseignes.create!(name: "Enseigne Tous", full_address: "1 rue tous", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "automatic"
    }

    assert_response :success
    assert_includes response.body, "Tous"
    assert_not_includes response.body, "Premier disponible"
    assert_select 'input[name="assignment_mode"][value="automatic"]', minimum: 1
    assert_select 'input[type="submit"][value="Tous"]', count: 1
  end

  test "show renders search mode step after assignment selection" do
    client = Client.create!(name: "Salon Search", slug: "salon-search")
    enseigne = client.enseignes.create!(name: "Enseigne Search", full_address: "1 rue search", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "automatic"
    }

    assert_response :success
    assert_select "h2", text: "4. Choisir le mode de recherche"
    assert_select 'input[name="search_mode"][value="first_available"]', count: 1
    assert_select 'input[name="search_mode"][value="precise_date"]', count: 1
    assert_select 'input[type="submit"][value="Premier créneau disponible"]', count: 1
    assert_select 'input[type="submit"][value="Date précise"]', count: 1
  end

  test "search mode step keeps enseigne service and assignment context" do
    client = Client.create!(name: "Salon Context", slug: "salon-context")
    enseigne = client.enseignes.create!(name: "Enseigne Context", full_address: "1 rue context", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "specific_staff",
      staff_id: staff.id
    }

    assert_response :success
    assert_select 'input[name="enseigne_id"][value=?]', enseigne.id.to_s, minimum: 1
    assert_select 'input[name="service_id"][value=?]', service.id.to_s, minimum: 1
    assert_select 'input[name="assignment_mode"][value="specific_staff"]', minimum: 1
    assert_select 'input[name="staff_id"][value=?]', staff.id.to_s, minimum: 1
  end

  test "show does not render date step before search mode selection" do
    client = Client.create!(name: "Salon No Date", slug: "salon-no-date")
    enseigne = client.enseignes.create!(name: "Enseigne No Date", full_address: "1 rue no date", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "automatic"
    }

    assert_response :success
    assert_select "h2", text: "5. Choisir une date", count: 0
    assert_select 'input[name="date"]', count: 0
  end

  test "show renders date step when search mode is precise_date" do
    client = Client.create!(name: "Salon Precise", slug: "salon-precise")
    enseigne = client.enseignes.create!(name: "Enseigne Precise", full_address: "1 rue precise", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      get public_client_url(client.slug), params: {
        enseigne_id: enseigne.id,
        service_id: service.id,
        assignment_mode: "automatic",
        search_mode: "precise_date"
      }

      assert_response :success
      assert_select "h2", text: "5. Choisir une date"
      assert_select 'input[name="search_mode"][value="precise_date"]', minimum: 1
      assert_select 'input[name="date"][min=?]', Date.current.iso8601
    end
  end

  test "show does not render slots step when search mode is first_available" do
    client = Client.create!(name: "Salon First", slug: "salon-first")
    enseigne = client.enseignes.create!(name: "Enseigne First", full_address: "1 rue first", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "automatic",
      search_mode: "first_available",
      date: Date.current.iso8601
    }

    assert_response :success
    assert_select "h2", text: "6. Choisir un créneau", count: 0
    assert_select 'input[name="start_time"]', count: 0
  end
end
