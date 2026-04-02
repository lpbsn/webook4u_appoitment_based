require "test_helper"
require Rails.root.join("db/migrate/20260402114000_update_bookings_service_consistency_to_enseigne")

class UpdateBookingsServiceConsistencyToEnseigneMigrationTest < SchemaMutationMigrationTestCase
  def setup
    @migration = UpdateBookingsServiceConsistencyToEnseigne.new
  end

  test "up installs trigger function that enforces service and booking enseigne consistency" do
    @migration.up

    function_sql = trigger_function_sql
    assert_includes function_sql, "bookings.enseigne_id must match services.enseigne_id"
    assert_includes function_sql, "bookings.client_id must match enseignes.client_id"
    assert_not_includes function_sql, "bookings.client_id must match services.client_id"
  ensure
    @migration.up
  end

  test "down restores legacy trigger function enforcing service client consistency" do
    @migration.down

    function_sql = trigger_function_sql
    assert_includes function_sql, "bookings.client_id must match services.client_id"
    assert_includes function_sql, "bookings.client_id must match enseignes.client_id"
    assert_not_includes function_sql, "bookings.enseigne_id must match services.enseigne_id"
  ensure
    @migration.up
  end

  private

  def trigger_function_sql
    result = ActiveRecord::Base.connection.execute(<<~SQL.squish).to_a
      SELECT pg_get_functiondef('enforce_bookings_client_consistency'::regproc) AS definition
    SQL

    result.first.fetch("definition")
  end
end
