require "test_helper"
require "open3"
require "pg"
require "securerandom"

class CreateFinalStaffBasedSchemaMigrationTest < SchemaMutationMigrationTestCase
  MIGRATION_VERSION = "20260403113000"

  test "baseline migration rebuilds a fresh database on its own" do
    database_name = "webook4u_baseline_#{SecureRandom.hex(6)}"
    create_database!(database_name)

    begin
      migrate_output, status = Open3.capture2e(
        {
          "RAILS_ENV" => "test",
          "DATABASE_URL" => "postgresql:///#{database_name}"
        },
        Rails.root.join("bin/rails").to_s,
        "db:migrate:up",
        "VERSION=#{MIGRATION_VERSION}"
      )

      assert status.success?, "Expected baseline migration to succeed.\n#{migrate_output}"

      assert_equal [ MIGRATION_VERSION ], schema_versions_for(database_name)
      assert table_exists_for?(database_name, "staffs")
      refute table_exists_for?(database_name, "client_opening_hours")
      assert constraint_exists_for?(database_name, "bookings_confirmed_no_overlapping_intervals_per_staff")
      refute constraint_exists_for?(database_name, "bookings_confirmed_no_overlapping_intervals_per_enseigne")
    ensure
      drop_database!(database_name)
    end
  end

  private

  def create_database!(database_name)
    with_postgres_connection do |connection|
      connection.exec("CREATE DATABASE #{connection.quote_ident(database_name)}")
    end
  end

  def drop_database!(database_name)
    with_postgres_connection do |connection|
      connection.exec_params(
        <<~SQL,
          SELECT pg_terminate_backend(pid)
          FROM pg_stat_activity
          WHERE datname = $1
            AND pid <> pg_backend_pid()
        SQL
        [ database_name ]
      )
      connection.exec("DROP DATABASE IF EXISTS #{connection.quote_ident(database_name)}")
    end
  end

  def schema_versions_for(database_name)
    with_database_connection(database_name) do |connection|
      connection.exec("SELECT version FROM schema_migrations ORDER BY version").column_values(0)
    end
  end

  def table_exists_for?(database_name, table_name)
    with_database_connection(database_name) do |connection|
      exists_value = connection.exec_params(
        <<~SQL,
          SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = $1
          ) AS exists
        SQL
        [ table_name ]
      ).first.fetch("exists")

      ActiveModel::Type::Boolean.new.cast(exists_value)
    end
  end

  def constraint_exists_for?(database_name, constraint_name)
    with_database_connection(database_name) do |connection|
      exists_value = connection.exec_params(
        <<~SQL,
          SELECT EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conname = $1
          ) AS exists
        SQL
        [ constraint_name ]
      ).first.fetch("exists")

      ActiveModel::Type::Boolean.new.cast(exists_value)
    end
  end

  def with_postgres_connection
    with_database_connection("postgres") { |connection| yield connection }
  end

  def with_database_connection(database_name)
    connection = PG.connect(dbname: database_name)
    yield connection
  ensure
    connection&.close
  end
end
