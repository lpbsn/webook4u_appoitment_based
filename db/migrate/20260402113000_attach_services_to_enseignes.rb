class AttachServicesToEnseignes < ActiveRecord::Migration[8.1]
  def up
    add_reference :services, :enseigne, foreign_key: true, null: true

    backfill_service_enseigne_ids!

    change_column_null :services, :enseigne_id, false
    change_column_null :services, :client_id, true
  end

  def down
    backfill_service_client_ids!

    change_column_null :services, :client_id, false
    remove_reference :services, :enseigne, foreign_key: true
  end

  private

  def backfill_service_enseigne_ids!
    missing_rows = execute(<<~SQL.squish).to_a
      SELECT s.id AS service_id, s.client_id
      FROM services s
      LEFT JOIN enseignes e ON e.client_id = s.client_id
      WHERE s.enseigne_id IS NULL
      GROUP BY s.id, s.client_id
      HAVING COUNT(e.id) = 0
      ORDER BY s.id
      LIMIT 20
    SQL

    if missing_rows.any?
      sample = missing_rows.map do |row|
        "service_id=#{row['service_id']} client_id=#{row['client_id']}"
      end.join("; ")

      raise <<~MESSAGE.squish
        Cannot backfill services.enseigne_id: some services belong to clients with no enseigne.
        Sample: #{sample}
      MESSAGE
    end

    execute <<~SQL
      UPDATE services s
      SET enseigne_id = canonical_enseigne.id
      FROM (
        SELECT client_id, MIN(id) AS id
        FROM enseignes
        GROUP BY client_id
      ) canonical_enseigne
      WHERE s.enseigne_id IS NULL
        AND canonical_enseigne.client_id = s.client_id;
    SQL

    null_count = select_value("SELECT COUNT(*) FROM services WHERE enseigne_id IS NULL").to_i
    return if null_count.zero?

    raise "Cannot enforce NOT NULL on services.enseigne_id: #{null_count} row(s) remain NULL after backfill."
  end

  def backfill_service_client_ids!
    execute <<~SQL
      UPDATE services s
      SET client_id = e.client_id
      FROM enseignes e
      WHERE s.client_id IS NULL
        AND s.enseigne_id = e.id;
    SQL

    null_count = select_value("SELECT COUNT(*) FROM services WHERE client_id IS NULL").to_i
    return if null_count.zero?

    raise "Cannot restore NOT NULL services.client_id: #{null_count} row(s) remain NULL after down backfill."
  end
end
