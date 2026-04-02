require "test_helper"
require Rails.root.join("db/migrate/20260402030000_harden_clients_name_constraints")

class HardenClientsNameConstraintsMigrationTest < SchemaMutationMigrationTestCase
  def setup
    @migration = HardenClientsNameConstraints.new
  end

  test "up raises when clients contain null or blank names" do
    @migration.down if clients_name_constraints_applied?

    timestamp = Time.current

    Client.insert_all!([
      { name: "", slug: "blank-client-name", created_at: timestamp, updated_at: timestamp }
    ])

    error = assert_raises(RuntimeError) { @migration.up }
    assert_includes error.message, "Cannot harden clients.name constraints"
  end

  private

  def clients_name_constraints_applied?
    ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT 1
      FROM pg_constraint
      WHERE conname = 'clients_name_not_blank'
      LIMIT 1
    SQL
  end
end
