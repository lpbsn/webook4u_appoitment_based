require "test_helper"
require Rails.root.join("db/migrate/20260401150000_harden_opening_hours_constraints")

class HardenOpeningHoursConstraintsMigrationTest < SchemaMutationMigrationTestCase
  def setup
    @migration = HardenOpeningHoursConstraints.new
  end

  test "migration removes exact duplicates automatically before adding constraints" do
    @migration.down

    client = Client.create!(name: "Client migration doublons", slug: "client-migration-doublons")
    enseigne = client.enseignes.create!(name: "Enseigne migration doublons")

    insert_client_opening_hour(client_id: client.id, day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    insert_client_opening_hour(client_id: client.id, day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    insert_client_opening_hour(client_id: client.id, day_of_week: 1, opens_at: "15:00", closes_at: "18:00")
    insert_client_opening_hour(client_id: client.id, day_of_week: 1, opens_at: "18:00", closes_at: "20:00")

    insert_enseigne_opening_hour(enseigne_id: enseigne.id, day_of_week: 2, opens_at: "10:00", closes_at: "13:00")
    insert_enseigne_opening_hour(enseigne_id: enseigne.id, day_of_week: 2, opens_at: "10:00", closes_at: "13:00")

    @migration.up

    client_rows = select_opening_hours("client_opening_hours", "client_id", client.id, 1)
    enseigne_rows = select_opening_hours("enseigne_opening_hours", "enseigne_id", enseigne.id, 2)

    assert_equal [
      [ "09:00:00", "12:00:00" ],
      [ "15:00:00", "18:00:00" ],
      [ "18:00:00", "20:00:00" ]
    ], client_rows

    assert_equal [
      [ "10:00:00", "13:00:00" ]
    ], enseigne_rows
  ensure
    @migration.up unless opening_hours_constraints_applied?
  end

  test "migration fails explicitly on non-trivial overlaps and does not merge rows" do
    @migration.down

    client = Client.create!(name: "Client migration overlap", slug: "client-migration-overlap")
    enseigne = client.enseignes.create!(name: "Enseigne migration overlap")

    insert_client_opening_hour(client_id: client.id, day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    insert_client_opening_hour(client_id: client.id, day_of_week: 1, opens_at: "11:00", closes_at: "14:00")
    insert_enseigne_opening_hour(enseigne_id: enseigne.id, day_of_week: 2, opens_at: "10:00", closes_at: "13:00")

    error = assert_raises(RuntimeError) { @migration.up }
    assert_includes error.message, "Cannot add opening hours overlap constraints on client_opening_hours"
    assert_includes error.message, "exact duplicates are cleaned automatically"
    assert_includes error.message, "non-trivial overlap pair(s) remain"
    assert_includes error.message, "not merged automatically"
    assert_includes error.message, "client_id=#{client.id}"
    assert_includes error.message, "day=1"

    client_rows = select_opening_hours("client_opening_hours", "client_id", client.id, 1)
    assert_equal [
      [ "09:00:00", "12:00:00" ],
      [ "11:00:00", "14:00:00" ]
    ], client_rows
  ensure
    ActiveRecord::Base.connection.execute(<<~SQL)
      DELETE FROM client_opening_hours
      WHERE client_id = #{client.id}
        AND day_of_week = 1
    SQL

    ActiveRecord::Base.connection.execute(<<~SQL)
      DELETE FROM enseigne_opening_hours
      WHERE enseigne_id = #{enseigne.id}
        AND day_of_week = 2
    SQL

    @migration.up unless opening_hours_constraints_applied?
  end

  private

  def insert_client_opening_hour(client_id:, day_of_week:, opens_at:, closes_at:)
    execute_insert(<<~SQL)
      INSERT INTO client_opening_hours (client_id, day_of_week, opens_at, closes_at, created_at, updated_at)
      VALUES (#{client_id}, #{day_of_week}, '#{opens_at}', '#{closes_at}', NOW(), NOW())
    SQL
  end

  def insert_enseigne_opening_hour(enseigne_id:, day_of_week:, opens_at:, closes_at:)
    execute_insert(<<~SQL)
      INSERT INTO enseigne_opening_hours (enseigne_id, day_of_week, opens_at, closes_at, created_at, updated_at)
      VALUES (#{enseigne_id}, #{day_of_week}, '#{opens_at}', '#{closes_at}', NOW(), NOW())
    SQL
  end

  def execute_insert(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  def select_opening_hours(table_name, parent_column, parent_id, day_of_week)
    ActiveRecord::Base.connection.select_rows(<<~SQL.squish)
      SELECT opens_at::text, closes_at::text
      FROM #{table_name}
      WHERE #{parent_column} = #{parent_id}
        AND day_of_week = #{day_of_week}
      ORDER BY opens_at, closes_at
    SQL
  end

  def opening_hours_constraints_applied?
    ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'client_opening_hours_no_overlapping_intervals_per_day'
      )
    SQL
  end
end
