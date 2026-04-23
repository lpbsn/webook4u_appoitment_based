# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

if Rails.env.development?
  upsert_weekday_hours = lambda do |relation, opens_at:, closes_at:|
    [ 1, 2, 3, 4, 5 ].each do |day_of_week|
      record = relation.find_or_initialize_by(day_of_week: day_of_week)
      record.opens_at = opens_at
      record.closes_at = closes_at
      record.save! if record.new_record? || record.changed?
    end
  end

  upsert_staff_capabilities = lambda do |staff, services|
    service_ids = services.map(&:id)
    staff.staff_service_capabilities.where.not(service_id: service_ids).delete_all

    service_ids.each do |service_id|
      staff.staff_service_capabilities.find_or_create_by!(service_id: service_id)
    end
  end

  salon = Client.find_or_create_by!(
    slug: "salon-des-gate"
  ) do |client|
    client.name = "Le Salon Des Gâté"
  end

  coach = Client.find_or_create_by!(
    slug: "maigris-mon-gros"
  ) do |client|
    client.name = "Maigris Mon Gros"
  end

  maad = Client.find_or_create_by!(
    slug: "maad-institute"
  ) do |client|
    client.name = "Maad Institute"
  end

  {
    salon => [
      {
        name: "PARIS 16 Salon",
        address: "108 Rue de la Tour",
        postal_code: "75116",
        city: "Paris",
        country: "France",
        active: true
      }
    ],
    coach => [
      {
        name: "LYON 06 Coach",
        address: "110 Rue Garibaldi",
        postal_code: "69006",
        city: "Lyon",
        country: "France",
        active: true
      },
      {
        name: "VALENCE SUD Coach",
        address: "79 Rue Barthélémy de Laffemas",
        postal_code: "26000",
        city: "Valence",
        country: "France",
        active: true
      },
      {
        name: "LYON 08 Coach",
        address: "2 Av. Paul Santy",
        postal_code: "69008",
        city: "Lyon",
        country: "France",
        active: false
      }
    ],
    maad => [
      {
        name: "Maad Paris",
        address: "22 Rue de Rivoli",
        postal_code: "75004",
        city: "Paris",
        country: "France",
        active: true
      },
      {
        name: "Maad Londres",
        address: "18 Harley Street",
        postal_code: "W1G 9PJ",
        city: "London",
        country: "United Kingdom",
        active: true
      },
      {
        name: "Maad Marseille",
        address: "41 Rue Paradis",
        postal_code: "13001",
        city: "Marseille",
        country: "France",
        active: true
      }
    ]
  }.each do |client, enseignes|
    enseignes.each do |attrs|
      enseigne = client.enseignes.find_or_initialize_by(name: attrs[:name])
      enseigne.assign_attributes(
        address: attrs[:address],
        postal_code: attrs[:postal_code],
        city: attrs[:city],
        country: attrs[:country],
        active: attrs[:active]
      )
      enseigne.save! if enseigne.new_record? || enseigne.changed?
    end
  end

  paris_16 = salon.enseignes.find_by!(name: "PARIS 16 Salon")
  lyon_06 = coach.enseignes.find_by!(name: "LYON 06 Coach")
  valence_sud = coach.enseignes.find_by!(name: "VALENCE SUD Coach")
  lyon_08 = coach.enseignes.find_by!(name: "LYON 08 Coach")
  maad_paris = maad.enseignes.find_by!(name: "Maad Paris")
  maad_londres = maad.enseignes.find_by!(name: "Maad Londres")
  maad_marseille = maad.enseignes.find_by!(name: "Maad Marseille")

  upsert_weekday_hours.call(paris_16.enseigne_opening_hours, opens_at: "09:00", closes_at: "18:00")
  upsert_weekday_hours.call(lyon_06.enseigne_opening_hours, opens_at: "10:00", closes_at: "16:00")
  upsert_weekday_hours.call(valence_sud.enseigne_opening_hours, opens_at: "10:00", closes_at: "16:00")
  lyon_08.enseigne_opening_hours.delete_all
  upsert_weekday_hours.call(maad_paris.enseigne_opening_hours, opens_at: "08:00", closes_at: "19:00")
  upsert_weekday_hours.call(maad_londres.enseigne_opening_hours, opens_at: "08:00", closes_at: "19:00")
  upsert_weekday_hours.call(maad_marseille.enseigne_opening_hours, opens_at: "08:00", closes_at: "19:00")

  [
    { name: "Coupe homme", duration_minutes: 30, price_cents: 3000 },
    { name: "Coupe femme", duration_minutes: 30, price_cents: 6000 },
    { name: "Brushing", duration_minutes: 30, price_cents: 10000 }
  ].each do |attrs|
    paris_16.services.find_or_create_by!(
      name: attrs[:name]
    ) do |service|
      service.duration_minutes = attrs[:duration_minutes]
      service.price_cents = attrs[:price_cents]
    end
  end

  [ lyon_06, valence_sud, lyon_08 ].each do |enseigne|
    [
      { name: "Séance individuelle", duration_minutes: 30, price_cents: 6000 },
      { name: "Bilan forme", duration_minutes: 30, price_cents: 3000 },
      { name: "Programme découverte", duration_minutes: 30, price_cents: 4000 }
    ].each do |attrs|
      enseigne.services.find_or_create_by!(
        name: attrs[:name]
      ) do |service|
        service.duration_minutes = attrs[:duration_minutes]
        service.price_cents = attrs[:price_cents]
      end
    end
  end

  [ maad_paris, maad_londres, maad_marseille ].each do |enseigne|
    [
      { name: "Bilan physiothérapie", legacy_name: "Bilan physiotherapie", duration_minutes: 45, price_cents: 7000 },
      { name: "Séance de physiothérapie", legacy_name: "Seance de physiotherapie", duration_minutes: 30, price_cents: 5500 },
      { name: "Rééducation fonctionnelle", legacy_name: "Reeducation fonctionnelle", duration_minutes: 45, price_cents: 6500 },
      { name: "Thérapie manuelle", legacy_name: "Therapie manuelle", duration_minutes: 30, price_cents: 6000 },
      { name: "Suivi post-opératoire", legacy_name: "Suivi post-operatoire", duration_minutes: 60, price_cents: 8500 }
    ].each do |attrs|
      service = enseigne.services.find_by(name: attrs[:name])
      legacy_service = enseigne.services.find_by(name: attrs[:legacy_name])

      if service.blank? && legacy_service.present?
        service = legacy_service
        service.name = attrs[:name]
      elsif service.present? && legacy_service.present? && legacy_service.id != service.id && legacy_service.bookings.none?
        legacy_service.destroy!
      end

      service ||= enseigne.services.new(name: attrs[:name])
      service.duration_minutes = attrs[:duration_minutes]
      service.price_cents = attrs[:price_cents]
      service.save! if service.new_record? || service.changed?
    end
  end

  [ paris_16, lyon_06, valence_sud, lyon_08, maad_paris, maad_londres, maad_marseille ].each do |enseigne|
    enseigne.services.find_each do |service|
      ServiceAssignmentCursor.find_or_create_by!(service: service)
    end
  end

  [
    { enseigne: paris_16, name: "Emma", active: true, opens_at: "09:00", closes_at: "18:00" },
    { enseigne: paris_16, name: "Nora", active: true, opens_at: "09:00", closes_at: "18:00" },
    { enseigne: lyon_06, name: "Lucas", active: true, opens_at: "10:00", closes_at: "16:00" },
    { enseigne: valence_sud, name: "Maya", active: true, opens_at: "10:00", closes_at: "16:00" },
    { enseigne: lyon_08, name: "Coach Inactif", active: false, opens_at: "10:00", closes_at: "16:00" }
  ].each do |attrs|
    enseigne = attrs[:enseigne]
    staff = enseigne.staffs.find_or_initialize_by(name: attrs[:name])
    staff.active = attrs[:active]
    staff.save! if staff.new_record? || staff.changed?

    if staff.active?
      upsert_weekday_hours.call(staff.staff_availabilities, opens_at: attrs[:opens_at], closes_at: attrs[:closes_at])
    else
      staff.staff_availabilities.delete_all
    end

    upsert_staff_capabilities.call(staff, enseigne.services.to_a)
  end

  [
    { enseigne: maad_paris, name: "Camille Bernard", active: true, opens_at: "08:00", closes_at: "16:00" },
    { enseigne: maad_paris, name: "Hugo Martin", active: true, opens_at: "09:00", closes_at: "17:00" },
    { enseigne: maad_paris, name: "Ines Leroy", active: true, opens_at: "11:00", closes_at: "19:00" },
    { enseigne: maad_londres, name: "Amelia Clarke", active: true, opens_at: "08:00", closes_at: "16:00" },
    { enseigne: maad_londres, name: "Noah Bennett", active: true, opens_at: "09:00", closes_at: "17:00" },
    { enseigne: maad_londres, name: "Sofia Evans", active: true, opens_at: "11:00", closes_at: "19:00" },
    { enseigne: maad_marseille, name: "Lea Moreau", active: true, opens_at: "08:00", closes_at: "16:00" },
    { enseigne: maad_marseille, name: "Thomas Ricci", active: true, opens_at: "09:00", closes_at: "17:00" },
    { enseigne: maad_marseille, name: "Nadia Benali", active: true, opens_at: "10:00", closes_at: "18:00" },
    { enseigne: maad_marseille, name: "Jules Garnier", active: true, opens_at: "11:00", closes_at: "19:00" }
  ].each do |attrs|
    enseigne = attrs[:enseigne]
    staff = enseigne.staffs.find_or_initialize_by(name: attrs[:name])
    staff.active = attrs[:active]
    staff.save! if staff.new_record? || staff.changed?

    upsert_weekday_hours.call(staff.staff_availabilities, opens_at: attrs[:opens_at], closes_at: attrs[:closes_at])
    upsert_staff_capabilities.call(staff, enseigne.services.to_a)
  end

  coach_service_name = "Séance individuelle"

  days_until_next_monday = (1 - BookingRules.business_today.wday) % 7
  days_until_next_monday = 7 if days_until_next_monday.zero?
  demo_date = BookingRules.business_today + days_until_next_monday.days

  [
    {
      enseigne: lyon_06,
      staff_name: "Lucas",
      booking_start_time: demo_date.in_time_zone.change(hour: 10, min: 0, sec: 0),
      booking_end_time: demo_date.in_time_zone.change(hour: 10, min: 30, sec: 0),
      customer_first_name: "Demo",
      customer_last_name: "Lyon",
      customer_email: "demo.lyon06@example.com"
    },
    {
      enseigne: valence_sud,
      staff_name: "Maya",
      booking_start_time: demo_date.in_time_zone.change(hour: 10, min: 0, sec: 0),
      booking_end_time: demo_date.in_time_zone.change(hour: 10, min: 30, sec: 0),
      customer_first_name: "Demo",
      customer_last_name: "Valence",
      customer_email: "demo.valence@example.com"
    },
    {
      enseigne: lyon_08,
      staff_name: "Coach Inactif",
      booking_start_time: demo_date.in_time_zone.change(hour: 11, min: 0, sec: 0),
      booking_end_time: demo_date.in_time_zone.change(hour: 11, min: 30, sec: 0),
      customer_first_name: "Demo",
      customer_last_name: "Inactive",
      customer_email: "demo.inactive@example.com"
    }
  ].each do |attrs|
    service = attrs[:enseigne].services.find_by!(name: coach_service_name)
    staff = attrs[:enseigne].staffs.find_by!(name: attrs[:staff_name])

    booking = coach.bookings.find_or_initialize_by(
      enseigne: attrs[:enseigne],
      service: service,
      booking_start_time: attrs[:booking_start_time]
    )
    booking.assign_attributes(
      staff: staff,
      booking_end_time: attrs[:booking_end_time],
      booking_status: :confirmed,
      customer_first_name: attrs[:customer_first_name],
      customer_last_name: attrs[:customer_last_name],
      customer_email: attrs[:customer_email]
    )
    booking.save! if booking.new_record? || booking.changed?
  end
end
