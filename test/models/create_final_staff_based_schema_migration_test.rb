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
          migration_context.up(#{MIGRATION_VERSION.to_i})
        RUBY
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
