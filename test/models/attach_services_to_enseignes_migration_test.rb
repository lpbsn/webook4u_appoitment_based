require "test_helper"
require Rails.root.join("db/migrate/20260402113000_attach_services_to_enseignes")

class AttachServicesToEnseignesMigrationTest < SchemaMutationMigrationTestCase
  def setup
    @migration = AttachServicesToEnseignes.new
  end

  test "up backfills enseigne_id with canonical enseigne per client and makes client_id nullable" do
    @migration.down
    Service.reset_column_information

    client = Client.create!(name: "Attach migration client", slug: "attach-migration-client")
    first_enseigne = client.enseignes.create!(name: "Enseigne 1")
    second_enseigne = client.enseignes.create!(name: "Enseigne 2")
    service_id = insert_service_row!(
      client_id: client.id,
      name: "Service pre-up",
      duration_minutes: 30,
      price_cents: 2500
    )

    @migration.up
    Service.reset_column_information

    service_row = fetch_service_row(service_id)
    assert_equal [ first_enseigne.id, second_enseigne.id ].min, service_row.fetch("enseigne_id").to_i
    assert_equal client.id, service_row.fetch("client_id").to_i
    assert service_columns.include?("enseigne_id")
    assert_equal true, service_column("client_id").null
  ensure
    @migration.up unless service_columns.include?("enseigne_id")
    Service.reset_column_information
  end

  test "up fails explicitly when a service belongs to a client without enseigne" do
    @migration.down
    Service.reset_column_information

    client_without_enseigne = Client.create!(
      name: "Attach migration no enseigne",
      slug: "attach-migration-no-enseigne"
    )
    service_id = insert_service_row!(
      client_id: client_without_enseigne.id,
      name: "Service orphan client",
      duration_minutes: 30,
      price_cents: 1500
    )

    error = assert_raises(RuntimeError) { @migration.up }
    assert_includes error.message, "Cannot backfill services.enseigne_id"
    assert_includes error.message, "some services belong to clients with no enseigne"
    assert_includes error.message, "service_id=#{service_id}"
  ensure
    execute_sql "DELETE FROM services WHERE id = #{service_id}" if defined?(service_id) && service_id.present?
    @migration.down if service_columns.include?("enseigne_id")
    @migration.up
    Service.reset_column_information
  end

  test "down backfills client_id from enseigne_id and removes enseigne_id column" do
    @migration.up unless service_columns.include?("enseigne_id")
    Service.reset_column_information

    client = Client.create!(name: "Attach migration down client", slug: "attach-migration-down-client")
    enseigne = client.enseignes.create!(name: "Down enseigne")
    service_id = insert_service_row!(
      enseigne_id: enseigne.id,
      client_id: nil,
      name: "Service pre-down",
      duration_minutes: 45,
      price_cents: 3000
    )

    @migration.down
    Service.reset_column_information

    service_row = fetch_service_row(service_id)
    assert_equal client.id, service_row.fetch("client_id").to_i
    assert_not service_columns.include?("enseigne_id")
    assert_equal false, service_column("client_id").null
  ensure
    @migration.up unless service_columns.include?("enseigne_id")
    Service.reset_column_information
  end

  private

  def service_columns
    ActiveRecord::Base.connection.columns(:services).map(&:name)
  end

  def service_column(name)
    ActiveRecord::Base.connection.columns(:services).find { |column| column.name == name.to_s }
  end

  def insert_service_row!(client_id: nil, enseigne_id: nil, name:, duration_minutes:, price_cents:)
    now = Time.current
    column_values = {
      name: name,
      duration_minutes: duration_minutes,
      price_cents: price_cents,
      created_at: now,
      updated_at: now
    }
    column_values[:client_id] = client_id if service_columns.include?("client_id")
    column_values[:enseigne_id] = enseigne_id if service_columns.include?("enseigne_id")

    columns = column_values.keys
    values = columns.map { |column| ActiveRecord::Base.connection.quote(column_values.fetch(column)) }

    result = execute_sql(<<~SQL.squish)
      INSERT INTO services (#{columns.join(', ')})
      VALUES (#{values.join(', ')})
      RETURNING id
    SQL

    result.first.fetch("id").to_i
  end

  def fetch_service_row(id)
    execute_sql("SELECT * FROM services WHERE id = #{id}").first
  end

  def execute_sql(sql)
    ActiveRecord::Base.connection.execute(sql).to_a
  end
end
