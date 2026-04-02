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
        WHERE conname = 'bookings_confirmed_no_overlapping_intervals_per_enseigne'
      )
    SQL

    assert constraint_exists, "Expected exclusion constraint for overlapping confirmed bookings to exist"
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
end
