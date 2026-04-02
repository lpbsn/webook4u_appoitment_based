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
    def create_weekday_opening_hours_for(client, opens_at: "09:00", closes_at: "18:00")
      [ 1, 2, 3, 4, 5 ].each do |day_of_week|
        client.client_opening_hours.create!(
          day_of_week: day_of_week,
          opens_at: opens_at,
          closes_at: closes_at
        )
      end
    end

    def create_weekday_opening_hours_for_enseigne(enseigne, opens_at: "09:00", closes_at: "18:00")
      [ 1, 2, 3, 4, 5 ].each do |day_of_week|
        enseigne.enseigne_opening_hours.create!(
          day_of_week: day_of_week,
          opens_at: opens_at,
          closes_at: closes_at
        )
      end
    end
  end
end

# Migration tests that call migration.up/down mutate the shared schema and must
# not run inside the normal parallel test workers.
class SchemaMutationMigrationTestCase < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
end
