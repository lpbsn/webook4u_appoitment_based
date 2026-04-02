ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    def create_weekday_opening_hours_for_enseigne(enseigne, opens_at: "09:00", closes_at: "18:00")
      [ 1, 2, 3, 4, 5 ].each do |day_of_week|
        enseigne.enseigne_opening_hours.create!(
          day_of_week: day_of_week,
          opens_at: opens_at,
          closes_at: closes_at
        )
      end
    end

    def create_service_for_enseigne(enseigne, name: "Service", duration_minutes: 30, price_cents: 3000)
      enseigne.services.create!(
        name: name,
        duration_minutes: duration_minutes,
        price_cents: price_cents
      )
    end

    def create_staff_for_enseigne(enseigne, name: "Staff", active: true)
      enseigne.staffs.create!(
        name: name,
        active: active
      )
    end

    def create_weekday_staff_availabilities_for(staff, opens_at: "09:00", closes_at: "18:00")
      [ 1, 2, 3, 4, 5 ].each do |day_of_week|
        staff.staff_availabilities.create!(
          day_of_week: day_of_week,
          opens_at: opens_at,
          closes_at: closes_at
        )
      end
    end

    def add_staff_capabilities(staff, services)
      services.each do |service|
        StaffServiceCapability.find_or_create_by!(
          staff: staff,
          service: service
        )
      end
    end

    def create_staff_based_setup(
      client:,
      enseigne_name: "Enseigne",
      service_name: "Service",
      staff_name: "Staff"
    )
      enseigne = client.enseignes.create!(name: enseigne_name, active: true)
      service = create_service_for_enseigne(enseigne, name: service_name)
      staff = create_staff_for_enseigne(enseigne, name: staff_name)

      create_weekday_opening_hours_for_enseigne(enseigne)
      create_weekday_staff_availabilities_for(staff)
      add_staff_capabilities(staff, [ service ])

      { enseigne: enseigne, service: service, staff: staff }
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def create_test_user(email: nil, password: "password123")
    generated_email = email || "user-#{SecureRandom.hex(6)}@example.com"
    User.create!(email: generated_email, password: password, password_confirmation: password)
  end
end

# Migration tests that call migration.up/down mutate the shared schema and must
# not run inside the normal parallel test workers.
class SchemaMutationMigrationTestCase < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
end
