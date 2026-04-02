require "test_helper"

class BookingsCrossTableTriggerInfrastructureTest < ActiveSupport::TestCase
  test "bootstraped database contains btree_gist extension for booking overlap protection" do
    extension_exists = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT EXISTS (
        SELECT 1
        FROM pg_extension
        WHERE extname = 'btree_gist'
      )
    SQL

    assert extension_exists, "Expected PostgreSQL extension btree_gist to exist in prepared database"
  end

  test "bootstraped database contains confirmed booking overlap exclusion constraint" do
    constraint_exists = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'bookings_confirmed_no_overlapping_intervals_per_staff'
      )
    SQL

    assert constraint_exists, "Expected exclusion constraint for overlapping confirmed bookings to exist"
  end

  test "bootstraped database contains confirmed booking requires staff check constraint" do
    constraint_exists = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'bookings_confirmed_requires_staff_id'
      )
    SQL

    assert constraint_exists, "Expected check constraint requiring staff for confirmed bookings to exist"
  end

  test "bootstraped database contains bookings cross-table consistency function" do
    function_exists = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE proname = 'enforce_bookings_client_consistency'
      )
    SQL

    assert function_exists, "Expected SQL function enforce_bookings_client_consistency to exist in prepared database"
  end

  test "bootstraped database contains bookings cross-table consistency trigger" do
    trigger_exists = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT EXISTS (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        WHERE t.tgname = 'bookings_client_consistency_trigger'
          AND c.relname = 'bookings'
          AND NOT t.tgisinternal
      )
    SQL

    assert trigger_exists, "Expected trigger bookings_client_consistency_trigger on bookings to exist in prepared database"
  end

  test "bootstraped consistency function includes staff to enseigne check" do
    function_sql = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
      SELECT pg_get_functiondef('enforce_bookings_client_consistency'::regproc)
    SQL

    assert_includes function_sql, "bookings.enseigne_id must match staffs.enseigne_id"
  end
end
