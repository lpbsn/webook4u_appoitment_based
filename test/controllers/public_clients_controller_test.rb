require "test_helper"

class PublicClientsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "GET show redirects authenticated users to their role dashboard by default" do
    client = Client.create!(name: "Salon Dashboard", slug: "salon-dashboard")
    user = create_test_user(client: client, role: :client_user)
    sign_in user

    get public_client_url(client.slug)

    assert_redirected_to client_root_path
  end

  test "GET show keeps booking flow accessible for authenticated users when booking entry is explicit" do
    client = Client.create!(name: "Salon Dashboard Booking", slug: "salon-dashboard-booking")
    client.enseignes.create!(name: "Enseigne active", address: "1 rue de Paris", postal_code: "00000", city: "Ville", country: "France", active: true)
    user = create_test_user(client: client, role: :client_user)
    sign_in user

    get public_client_url(client.slug), params: { booking_entry: "1" }

    assert_response :success
  end

  test "GET show returns success for valid client slug" do
    client = Client.create!(name: "Salon", slug: "salon")
    client.enseignes.create!(name: "Enseigne active", address: "1 rue de Paris", postal_code: "00000", city: "Ville", country: "France", active: true)
    get public_client_url(client.slug)
    assert_response :success
  end

  test "GET show returns 404 for unknown client slug" do
    get public_client_url("slug-inexistant-xyz")
    assert_response :not_found
  end

  test "precise date planning starts today and does not offer previous week" do
    client = Client.create!(name: "Salon Min", slug: "salon-min")
    enseigne = client.enseignes.create!(name: "Enseigne Min", address: "1 rue min", postal_code: "00000", city: "Ville", country: "France", active: true)
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
      assert_select ".booking-planning"
      assert_select ".booking-planning-nav-button--disabled", text: "Semaine précédente"
      assert_select 'input[name="date"][value=?]', Date.current.iso8601, count: 0
    end
  end

  test "rejects date beyond max_future_days and falls back to current planning window" do
    client = Client.create!(name: "Salon", slug: "salon")
    enseigne = client.enseignes.create!(name: "Enseigne active", address: "1 rue de Paris", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      date_beyond = (Date.current + (BookingRules.max_future_days + 1).days).iso8601
      get public_client_url(client.slug), params: {
        enseigne_id: enseigne.id,
        service_id: service.id,
        assignment_mode: "automatic",
        search_mode: "precise_date",
        date: date_beyond
      }
      assert_response :success
      assert_select ".booking-planning"
      assert_select 'input[name="date"][value=?]', Date.current.iso8601, count: 0
    end
  end

  test "show lists only active enseignes" do
    client = Client.create!(name: "Salon Enseignes", slug: "salon-enseignes")
    active_enseigne = client.enseignes.create!(name: "Enseigne active", address: "1 rue active", postal_code: "00000", city: "Ville", country: "France", active: true)
    client.enseignes.create!(name: "Enseigne inactive", address: "2 rue inactive", postal_code: "00000", city: "Ville", country: "France", active: false)

    get public_client_url(client.slug)

    assert_response :success
    assert_includes response.body, active_enseigne.name
    assert_includes response.body, active_enseigne.formatted_address
    assert_not_includes response.body, "Enseigne inactive"
  end

  test "show does not render service step when several active enseignes exist without selection" do
    client = Client.create!(name: "Salon Multi", slug: "salon-multi")
    enseigne_a = client.enseignes.create!(name: "Enseigne A", address: "1 rue A", postal_code: "00000", city: "Ville", country: "France", active: true)
    client.enseignes.create!(name: "Enseigne B", address: "2 rue B", postal_code: "00000", city: "Ville", country: "France", active: true)
    enseigne_a.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    get public_client_url(client.slug)

    assert_response :success
    assert_select "h2", text: "1. Choisir une enseigne"
    assert_select "h2", text: "2. Choisir un service", count: 0
  end

  test "show displays unavailable tunnel message when no active enseigne exists" do
    client = Client.create!(name: "Salon Vide", slug: "salon-vide")
    client.enseignes.create!(name: "Inactive", address: "3 rue vide", postal_code: "00000", city: "Ville", country: "France", active: false)

    get public_client_url(client.slug)

    assert_response :success
    assert_includes response.body, "Aucune enseigne active n'est disponible pour le moment."
  end

  test "show auto-selects the single active enseigne and keeps the flow usable" do
    client = Client.create!(name: "Salon Single", slug: "salon-single")
    enseigne = client.enseignes.create!(name: "Enseigne unique", address: "1 rue unique", postal_code: "00000", city: "Ville", country: "France", active: true)
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
    enseigne = client.enseignes.create!(name: "Enseigne Tous", address: "1 rue tous", postal_code: "00000", city: "Ville", country: "France", active: true)
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
    enseigne = client.enseignes.create!(name: "Enseigne Search", address: "1 rue search", postal_code: "00000", city: "Ville", country: "France", active: true)
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
    enseigne = client.enseignes.create!(name: "Enseigne Context", address: "1 rue context", postal_code: "00000", city: "Ville", country: "France", active: true)
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

  test "show does not render precise date planning before search mode selection" do
    client = Client.create!(name: "Salon No Date", slug: "salon-no-date")
    enseigne = client.enseignes.create!(name: "Enseigne No Date", address: "1 rue no date", postal_code: "00000", city: "Ville", country: "France", active: true)
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
    assert_select "h2", text: "5. Choisir un créneau", count: 0
    assert_select ".booking-planning", count: 0
  end

  test "show renders precise date planning when search mode is precise_date" do
    client = Client.create!(name: "Salon Precise", slug: "salon-precise")
    enseigne = client.enseignes.create!(name: "Enseigne Precise", address: "1 rue precise", postal_code: "00000", city: "Ville", country: "France", active: true)
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
      assert_select "h2", text: "5. Choisir un créneau"
      assert_select ".booking-planning"
      assert_select ".booking-planning-day", minimum: 1
      assert_select 'input[name="search_mode"][value="precise_date"]', minimum: 1
    end
  end

  test "show does not render slots step when search mode is first_available" do
    client = Client.create!(name: "Salon First", slug: "salon-first")
    enseigne = client.enseignes.create!(name: "Enseigne First", address: "1 rue first", postal_code: "00000", city: "Ville", country: "France", active: true)
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

  test "show renders first available criteria step when search mode is first_available" do
    client = Client.create!(name: "Salon First Available", slug: "salon-first-available")
    enseigne = client.enseignes.create!(name: "Enseigne First Available", address: "1 rue fa", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "automatic",
      search_mode: "first_available"
    }

    assert_response :success
    assert_select "h2", text: "5. Définir vos critères"
    assert_select 'input[name="selected_days_of_week[]"]', minimum: 1
    assert_select 'input[name="start_time_min"]', count: 1
    assert_select 'input[name="start_time_max"]', count: 1
  end

  test "show first available criteria step keeps enseigne service assignment and search mode context" do
    client = Client.create!(name: "Salon Criteria Context", slug: "salon-criteria-context")
    enseigne = client.enseignes.create!(name: "Enseigne Criteria Context", address: "1 rue context", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "specific_staff",
      staff_id: staff.id,
      search_mode: "first_available"
    }

    assert_response :success
    assert_select 'input[name="enseigne_id"][value=?]', enseigne.id.to_s, minimum: 1
    assert_select 'input[name="service_id"][value=?]', service.id.to_s, minimum: 1
    assert_select 'input[name="assignment_mode"][value="specific_staff"]', minimum: 1
    assert_select 'input[name="staff_id"][value=?]', staff.id.to_s, minimum: 1
    assert_select 'input[name="search_mode"][value="first_available"]', minimum: 1
  end

  test "show first available criteria step displays only days open for enseigne and selected staff scope" do
    client = Client.create!(name: "Salon Open Days", slug: "salon-open-days")
    enseigne = client.enseignes.create!(name: "Enseigne Open Days", address: "1 rue open", postal_code: "00000", city: "Ville", country: "France", active: true)
    enseigne.enseigne_opening_hours.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    enseigne.enseigne_opening_hours.create!(day_of_week: 2, opens_at: "09:00", closes_at: "18:00")

    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "specific_staff",
      staff_id: staff.id,
      search_mode: "first_available"
    }

    assert_response :success
    assert_select 'input[name="selected_days_of_week[]"][value="1"]', count: 1
    assert_select 'input[name="selected_days_of_week[]"][value="2"]', count: 0
  end

  test "show first available criteria step shows validation error when no day is selected" do
    client = Client.create!(name: "Salon No Day", slug: "salon-no-day")
    enseigne = client.enseignes.create!(name: "Enseigne No Day", address: "1 rue no day", postal_code: "00000", city: "Ville", country: "France", active: true)
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
      start_time_min: "09:00",
      start_time_max: "18:00"
    }

    assert_response :success
    assert_includes response.body, "Sélectionnez au moins un jour."
  end

  test "show first available criteria step shows validation error when start_time_min is missing" do
    client = Client.create!(name: "Salon Missing Min", slug: "salon-missing-min")
    enseigne = client.enseignes.create!(name: "Enseigne Missing Min", address: "1 rue min", postal_code: "00000", city: "Ville", country: "France", active: true)
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
      selected_days_of_week: [ "1" ],
      start_time_max: "18:00"
    }

    assert_response :success
    assert_select ".booking-alert--error li", text: "L'heure de début minimale est obligatoire."
  end

  test "show first available criteria step shows validation error when start_time_max is missing" do
    client = Client.create!(name: "Salon Missing Max", slug: "salon-missing-max")
    enseigne = client.enseignes.create!(name: "Enseigne Missing Max", address: "1 rue max", postal_code: "00000", city: "Ville", country: "France", active: true)
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
      selected_days_of_week: [ "1" ],
      start_time_min: "09:00"
    }

    assert_response :success
    assert_select ".booking-alert--error li", text: "L'heure de début maximale est obligatoire."
  end

  test "show first available criteria step shows validation error when start_time_min is after start_time_max" do
    client = Client.create!(name: "Salon Invalid Range", slug: "salon-invalid-range")
    enseigne = client.enseignes.create!(name: "Enseigne Invalid Range", address: "1 rue range", postal_code: "00000", city: "Ville", country: "France", active: true)
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
      selected_days_of_week: [ "1" ],
      start_time_min: "18:00",
      start_time_max: "09:00"
    }

    assert_response :success
    assert_select ".booking-alert--error li",
                  text: "L'heure de début minimale doit être inférieure ou égale à l'heure de début maximale."
  end

  test "show displays first available suggestion when a slot is found" do
    client = Client.create!(name: "Salon Suggestion", slug: "salon-suggestion")
    enseigne = client.enseignes.create!(name: "Enseigne Suggestion", address: "1 rue suggestion", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      assert_no_difference("Booking.count") do
        get public_client_url(client.slug), params: {
          enseigne_id: enseigne.id,
          service_id: service.id,
          assignment_mode: "automatic",
          search_mode: "first_available",
          selected_days_of_week: [ "1" ],
          start_time_min: "09:00",
          start_time_max: "18:00"
        }
      end

      assert_response :success
      assert_select "h2", text: "6. Premier créneau disponible"
      assert_includes response.body, "Créneau suggéré :"
      assert_includes response.body, "09:00"
      assert_select "form[action=?]", service_bookings_path(client.slug, service), count: 1
      assert_select 'input[name="start_time"]', count: 1
      assert_select 'input[type="submit"][value="Continuer avec ce créneau"]', count: 1
    end
  end

  test "show displays no result message when no first available slot matches criteria" do
    client = Client.create!(name: "Salon No Result", slug: "salon-no-result")
    enseigne = client.enseignes.create!(name: "Enseigne No Result", address: "1 rue no result", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      assert_no_difference("Booking.count") do
        get public_client_url(client.slug), params: {
          enseigne_id: enseigne.id,
          service_id: service.id,
          assignment_mode: "automatic",
          search_mode: "first_available",
          selected_days_of_week: [ "3" ],
          start_time_min: "15:00",
          start_time_max: "16:00"
        }
      end

      assert_response :success
      assert_select "h2", text: "6. Premier créneau disponible"
      assert_includes response.body, "Aucun créneau disponible ne correspond à vos critères."
    end
  end

  test "show does not display first available result block before a valid search is performed" do
    client = Client.create!(name: "Salon No Search Yet", slug: "salon-no-search-yet")
    enseigne = client.enseignes.create!(name: "Enseigne No Search Yet", address: "1 rue no search", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "automatic",
      search_mode: "first_available"
    }

    assert_response :success
    assert_select "h2", text: "6. Premier créneau disponible", count: 0
  end

  test "clicking a precise_date slot is now a GET selection and does not create a pending booking" do
    client = Client.create!(name: "Salon Select Slot", slug: "salon-select-slot")
    enseigne = client.enseignes.create!(name: "Enseigne Select Slot", address: "1 rue slot", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      selected_slot = Time.zone.local(2026, 3, 16, 9, 0, 0)

      assert_no_difference("Booking.count") do
        get public_client_url(client.slug), params: {
          enseigne_id: enseigne.id,
          service_id: service.id,
          assignment_mode: "automatic",
          search_mode: "precise_date",
          date: "2026-03-16",
          selected_start_time: selected_slot
        }
      end

      assert_response :success
      assert_select 'input[name="selected_start_time"]', minimum: 1
      assert_select "form[action=?]", service_bookings_path(client.slug, service), minimum: 1
      assert_includes response.body, "Confirmer ce créneau"
    end
  end

  test "first available suggestion renders a direct pending creation action without confirmation step" do
    client = Client.create!(name: "Salon Suggestion Select", slug: "salon-suggestion-select")
    enseigne = client.enseignes.create!(name: "Enseigne Suggestion Select", address: "1 rue suggestion", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      assert_no_difference("Booking.count") do
        get public_client_url(client.slug), params: {
          enseigne_id: enseigne.id,
          service_id: service.id,
          assignment_mode: "automatic",
          search_mode: "first_available",
          selected_days_of_week: [ "1" ],
          start_time_min: "09:00",
          start_time_max: "18:00"
        }
      end

      assert_response :success
      assert_select "form[action=?]", service_bookings_path(client.slug, service), count: 1
      assert_select 'input[name="selected_start_time"]', count: 0
      assert_select 'input[name="start_time"]', count: 1
      assert_includes response.body, "Continuer avec ce créneau"
      assert_not_includes response.body, "Confirmer ce créneau"
    end
  end

  test "summary shows automatic assignment as Tous" do
    client = Client.create!(name: "Salon Summary Tous", slug: "salon-summary-tous")
    enseigne = client.enseignes.create!(name: "Enseigne Summary Tous", address: "1 rue tous", postal_code: "00000", city: "Ville", country: "France", active: true)
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
    assert_includes response.body, "Attribution :"
    assert_includes response.body, "Tous"
  end

  test "summary shows precise_date search mode label" do
    client = Client.create!(name: "Salon Summary Precise", slug: "salon-summary-precise")
    enseigne = client.enseignes.create!(name: "Enseigne Summary Precise", address: "1 rue precise", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "automatic",
      search_mode: "precise_date"
    }

    assert_response :success
    assert_includes response.body, "Mode de recherche :"
    assert_includes response.body, "Date précise"
  end

  test "summary shows first_available search mode label" do
    client = Client.create!(name: "Salon Summary First", slug: "salon-summary-first")
    enseigne = client.enseignes.create!(name: "Enseigne Summary First", address: "1 rue first", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    get public_client_url(client.slug), params: {
      enseigne_id: enseigne.id,
      service_id: service.id,
      assignment_mode: "automatic",
      search_mode: "first_available"
    }

    assert_response :success
    assert_includes response.body, "Mode de recherche :"
    assert_includes response.body, "Premier créneau disponible"
  end

  test "summary shows selected precise_date slot in date and slot rows" do
    client = Client.create!(name: "Salon Summary Slot", slug: "salon-summary-slot")
    enseigne = client.enseignes.create!(name: "Enseigne Summary Slot", address: "1 rue slot", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    selected_start_time = Time.zone.local(2026, 3, 16, 10, 30, 0)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      get public_client_url(client.slug), params: {
        enseigne_id: enseigne.id,
        service_id: service.id,
        assignment_mode: "automatic",
        search_mode: "precise_date",
        date: "2026-03-16",
        selected_start_time: selected_start_time
      }

      assert_response :success
      assert_includes response.body, "Mode de recherche :"
      assert_includes response.body, "Date précise"
      assert_includes response.body, "16/03/2026"
      assert_includes response.body, "10:30"
    end
  end

  test "summary shows first available suggestion when no selected slot exists" do
    client = Client.create!(name: "Salon Summary Suggestion", slug: "salon-summary-suggestion")
    enseigne = client.enseignes.create!(name: "Enseigne Summary Suggestion", address: "1 rue suggestion", postal_code: "00000", city: "Ville", country: "France", active: true)
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
        search_mode: "first_available",
        selected_days_of_week: [ 1 ],
        start_time_min: "10:00",
        start_time_max: "12:00"
      }

      assert_response :success
      assert_includes response.body, "Mode de recherche :"
      assert_includes response.body, "Premier créneau disponible"
      assert_includes response.body, "16/03/2026"
      assert_includes response.body, "10:00"
    end
  end

  test "summary prioritizes selected_start_time over first available suggestion" do
    client = Client.create!(name: "Salon Summary Priority", slug: "salon-summary-priority")
    enseigne = client.enseignes.create!(name: "Enseigne Summary Priority", address: "1 rue priority", postal_code: "00000", city: "Ville", country: "France", active: true)
    create_weekday_opening_hours_for_enseigne(enseigne)
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)

    staff = enseigne.staffs.create!(name: "Emma", active: true)
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "10:00", closes_at: "18:00")
    StaffServiceCapability.create!(staff: staff, service: service)

    selected_start_time = Time.zone.local(2026, 3, 16, 11, 0, 0)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      get public_client_url(client.slug), params: {
        enseigne_id: enseigne.id,
        service_id: service.id,
        assignment_mode: "automatic",
        search_mode: "first_available",
        selected_days_of_week: [ 1 ],
        start_time_min: "10:00",
        start_time_max: "12:00",
        selected_start_time: selected_start_time
      }

      assert_response :success
      assert_includes response.body, "Mode de recherche :"
      assert_includes response.body, "Premier créneau disponible"
      assert_includes response.body, "16/03/2026"
      assert_includes response.body, "11:00"
    end
  end
end
