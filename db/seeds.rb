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

  {
    salon => [
      {
        name: "PARIS 16 Salon",
        full_address: "108 Rue de la Tour, 75116 Paris",
        active: true
      }
    ],
    coach => [
      {
        name: "LYON 06 Coach",
        full_address: "110 Rue Garibaldi, 69006 Lyon, France",
        active: true
      },
      {
        name: "VALENCE SUD Coach",
        full_address: "79 Rue Barthélémy de Laffemas, 26000 Valence, France",
        active: true
      },
      {
        name: "LYON 08 Coach",
        full_address: "2 Av. Paul Santy, 69008 Lyon, France",
        active: false
      }
    ]
  }.each do |client, enseignes|
    enseignes.each do |attrs|
      enseigne = client.enseignes.find_or_initialize_by(name: attrs[:name])
      enseigne.assign_attributes(
        full_address: attrs[:full_address],
        active: attrs[:active]
      )
      enseigne.save! if enseigne.new_record? || enseigne.changed?
    end
  end

  upsert_weekday_hours.call(salon.client_opening_hours, opens_at: "09:00", closes_at: "18:00")
  upsert_weekday_hours.call(coach.client_opening_hours, opens_at: "09:00", closes_at: "18:00")

  paris_16 = salon.enseignes.find_by!(name: "PARIS 16 Salon")
  lyon_06 = coach.enseignes.find_by!(name: "LYON 06 Coach")
  valence_sud = coach.enseignes.find_by!(name: "VALENCE SUD Coach")
  lyon_08 = coach.enseignes.find_by!(name: "LYON 08 Coach")

  upsert_weekday_hours.call(lyon_06.enseigne_opening_hours, opens_at: "10:00", closes_at: "16:00")
  valence_sud.enseigne_opening_hours.delete_all
  lyon_08.enseigne_opening_hours.delete_all

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

  coach_service_name = "Séance individuelle"

  days_until_next_monday = (1 - BookingRules.business_today.wday) % 7
  days_until_next_monday = 7 if days_until_next_monday.zero?
  demo_date = BookingRules.business_today + days_until_next_monday.days

  [
    {
      enseigne: lyon_06,
      booking_start_time: demo_date.in_time_zone.change(hour: 10, min: 0, sec: 0),
      booking_end_time: demo_date.in_time_zone.change(hour: 10, min: 30, sec: 0),
      customer_first_name: "Demo",
      customer_last_name: "Lyon",
      customer_email: "demo.lyon06@example.com"
    },
    {
      enseigne: valence_sud,
      booking_start_time: demo_date.in_time_zone.change(hour: 10, min: 0, sec: 0),
      booking_end_time: demo_date.in_time_zone.change(hour: 10, min: 30, sec: 0),
      customer_first_name: "Demo",
      customer_last_name: "Valence",
      customer_email: "demo.valence@example.com"
    },
    {
      enseigne: lyon_08,
      booking_start_time: demo_date.in_time_zone.change(hour: 11, min: 0, sec: 0),
      booking_end_time: demo_date.in_time_zone.change(hour: 11, min: 30, sec: 0),
      customer_first_name: "Demo",
      customer_last_name: "Inactive",
      customer_email: "demo.inactive@example.com"
    }
  ].each do |attrs|
    service = attrs[:enseigne].services.find_by!(name: coach_service_name)

    booking = coach.bookings.find_or_initialize_by(
      enseigne: attrs[:enseigne],
      service: service,
      booking_start_time: attrs[:booking_start_time]
    )
    booking.assign_attributes(
      booking_end_time: attrs[:booking_end_time],
      booking_status: :confirmed,
      customer_first_name: attrs[:customer_first_name],
      customer_last_name: attrs[:customer_last_name],
      customer_email: attrs[:customer_email]
    )
    booking.save! if booking.new_record? || booking.changed?
  end
end
