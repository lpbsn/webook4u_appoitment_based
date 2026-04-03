require "test_helper"
require "open3"
require "pg"
require "securerandom"

class CreateFinalStaffBasedSchemaMigrationTest < SchemaMutationMigrationTestCase
  BASELINE_MIGRATION_VERSION = "20260403113000"
  LATEST_MIGRATION_VERSION = "20260403120000"
  EXPECTED_SCHEMA_VERSIONS = [
    BASELINE_MIGRATION_VERSION,
    LATEST_MIGRATION_VERSION
  ].freeze

  test "schema migrations rebuild a fresh database to the latest schema" do
    database_name = "webook4u_baseline_#{SecureRandom.hex(6)}"
    create_database!(database_name)

    begin
      migrate_database_to!(database_name, LATEST_MIGRATION_VERSION)

      assert_equal EXPECTED_SCHEMA_VERSIONS, schema_versions_for(database_name)
      assert table_exists_for?(database_name, "staffs")
      refute table_exists_for?(database_name, "client_opening_hours")
      assert constraint_exists_for?(database_name, "bookings_confirmed_no_overlapping_intervals_per_staff")
      assert constraint_exists_for?(database_name, "bookings_assignment_mode_allowed_values")
      refute constraint_exists_for?(database_name, "bookings_confirmed_no_overlapping_intervals_per_enseigne")

      column = column_definition_for(database_name, "bookings", "assignment_mode")
      assert_equal "character varying", column.fetch("data_type")
      assert_equal "NO", column.fetch("is_nullable")
      assert_includes column.fetch("column_default"), "automatic"

      constraint_definition = constraint_definition_for(database_name, "bookings_assignment_mode_allowed_values")
      assert_includes constraint_definition, "assignment_mode"
      assert_includes constraint_definition, "automatic"
      assert_includes constraint_definition, "specific_staff"
    ensure
      drop_database!(database_name)
    end
  end

  test "latest migration backfills existing bookings to automatic assignment_mode" do
    database_name = "webook4u_assignment_mode_backfill_#{SecureRandom.hex(6)}"
    create_database!(database_name)

    begin
      migrate_database_to!(database_name, BASELINE_MIGRATION_VERSION)
      booking_id = insert_booking_without_assignment_mode!(database_name)

      migrate_database_to!(database_name, LATEST_MIGRATION_VERSION)

      assert_equal "automatic", booking_assignment_mode_for(database_name, booking_id)
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

  def column_definition_for(database_name, table_name, column_name)
    with_database_connection(database_name) do |connection|
      connection.exec_params(
        <<~SQL,
          SELECT data_type, is_nullable, column_default
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = $1
            AND column_name = $2
        SQL
        [ table_name, column_name ]
      ).first
    end
  end

  def constraint_definition_for(database_name, constraint_name)
    with_database_connection(database_name) do |connection|
      connection.exec_params(
        <<~SQL,
          SELECT pg_get_constraintdef(oid) AS definition
          FROM pg_constraint
          WHERE conname = $1
        SQL
        [ constraint_name ]
      ).first.fetch("definition")
    end
  end

  def booking_assignment_mode_for(database_name, booking_id)
    with_database_connection(database_name) do |connection|
      connection.exec_params(
        "SELECT assignment_mode FROM bookings WHERE id = $1",
        [ booking_id ]
      ).first.fetch("assignment_mode")
    end
  end

  def insert_booking_without_assignment_mode!(database_name)
    with_database_connection(database_name) do |connection|
      client_id = connection.exec_params(
        "INSERT INTO clients (name, slug, created_at, updated_at) VALUES ($1, $2, NOW(), NOW()) RETURNING id",
        [ "Client migration", "client-migration-#{SecureRandom.hex(4)}" ]
      ).first.fetch("id")

      enseigne_id = connection.exec_params(
        "INSERT INTO enseignes (client_id, name, created_at, updated_at) VALUES ($1, $2, NOW(), NOW()) RETURNING id",
        [ client_id, "Enseigne migration" ]
      ).first.fetch("id")

      service_id = connection.exec_params(
        <<~SQL,
          INSERT INTO services (enseigne_id, name, duration_minutes, price_cents, created_at, updated_at)
          VALUES ($1, $2, $3, $4, NOW(), NOW())
          RETURNING id
        SQL
        [ enseigne_id, "Service migration", 30, 2500 ]
      ).first.fetch("id")

      connection.exec_params(
        <<~SQL,
          INSERT INTO bookings (
            client_id,
            enseigne_id,
            service_id,
            booking_start_time,
            booking_end_time,
            booking_status,
            created_at,
            updated_at
          )
          VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
          RETURNING id
        SQL
        [
          client_id,
          enseigne_id,
          service_id,
          Time.utc(2026, 4, 3, 9, 0, 0),
          Time.utc(2026, 4, 3, 9, 30, 0),
          "failed"
        ]
      ).first.fetch("id")
    end
  end

  def migrate_database_to!(database_name, version)
    migrate_output, status = Open3.capture2e(
      child_process_env_for(database_name),
      Rails.root.join("bin/rails").to_s,
      "runner",
      <<~RUBY
        connection_config = {
          adapter: "postgresql",
          database: ENV.fetch("PGDATABASE")
        }

        connection_config[:host] = ENV["PGHOST"] if ENV["PGHOST"].present?
        connection_config[:port] = ENV["PGPORT"] if ENV["PGPORT"].present?
        connection_config[:username] = ENV["PGUSER"] if ENV["PGUSER"].present?
        connection_config[:password] = ENV["PGPASSWORD"] if ENV["PGPASSWORD"].present?

        ActiveRecord::Base.establish_connection(connection_config)
        ActiveRecord.dump_schema_after_migration = false
        migration_context = ActiveRecord::Base.connection_pool.migration_context
        migration_context.schema_migration.create_table
        migration_context.internal_metadata.create_table
        migration_context.up(#{version.to_i})
      RUBY
    )

    assert status.success?, "Expected migrations through #{version} to succeed.\n#{migrate_output}"
  end

  def with_postgres_connection
    with_database_connection("postgres") { |connection| yield connection }
  end

  def with_database_connection(database_name)
    connection = PG.connect(base_pg_connection_params.merge(dbname: database_name))
    yield connection
  ensure
    connection&.close
  end

  def base_pg_connection_params
    @base_pg_connection_params ||= begin
      db_config = Array(ActiveRecord::Base.configurations.configs_for(env_name: "test", name: "primary")).first ||
        Array(ActiveRecord::Base.configurations.configs_for(env_name: "test")).first
      configuration_hash = db_config.configuration_hash.symbolize_keys

      {
        host: configuration_hash[:host].presence,
        port: configuration_hash[:port].presence,
        user: configuration_hash[:username].presence,
        password: configuration_hash[:password].presence
      }.compact
    end
  end

  def child_process_env_for(database_name)
    env = {
      "RAILS_ENV" => "test",
      "PGDATABASE" => database_name
    }

    env["PGHOST"] = base_pg_connection_params[:host].to_s if base_pg_connection_params[:host].present?
    env["PGPORT"] = base_pg_connection_params[:port].to_s if base_pg_connection_params[:port].present?
    env["PGUSER"] = base_pg_connection_params[:user].to_s if base_pg_connection_params[:user].present?
    env["PGPASSWORD"] = base_pg_connection_params[:password].to_s if base_pg_connection_params[:password].present?

    env
  end
end
