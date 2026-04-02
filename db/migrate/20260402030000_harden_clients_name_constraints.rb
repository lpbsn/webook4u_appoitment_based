class HardenClientsNameConstraints < ActiveRecord::Migration[8.1]
  NAME_NOT_BLANK_CONSTRAINT = "clients_name_not_blank"

  def up
    execute <<~SQL
      UPDATE clients
      SET name = NULL
      WHERE NULLIF(BTRIM(name), '') IS NULL;
    SQL

    if select_value("SELECT COUNT(*) FROM clients WHERE name IS NULL").to_i.positive?
      raise <<~MSG.squish
        Cannot harden clients.name constraints: found clients with NULL or blank names.
        Backfill client names before retrying this migration.
      MSG
    end

    change_column_null :clients, :name, false

    add_check_constraint :clients,
                         "NULLIF(BTRIM(name), '') IS NOT NULL",
                         name: NAME_NOT_BLANK_CONSTRAINT
  end

  def down
    remove_check_constraint :clients, name: NAME_NOT_BLANK_CONSTRAINT
    change_column_null :clients, :name, true
  end
end
