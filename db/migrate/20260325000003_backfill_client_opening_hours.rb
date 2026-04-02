class BackfillClientOpeningHours < ActiveRecord::Migration[8.1]
  class MigrationClient < ActiveRecord::Base
    self.table_name = "clients"

    has_many :client_opening_hours,
             class_name: "BackfillClientOpeningHours::MigrationClientOpeningHour",
             foreign_key: :client_id
  end

  class MigrationClientOpeningHour < ActiveRecord::Base
    self.table_name = "client_opening_hours"
  end

  def up
    MigrationClient.find_each do |client|
      next if client.client_opening_hours.exists?

      weekday_rows.each do |attrs|
        client.client_opening_hours.create!(attrs)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot safely distinguish backfilled opening hours from manually created ones"
  end

  private

  def weekday_rows
    @weekday_rows ||= [ 1, 2, 3, 4, 5 ].map do |day_of_week|
      {
        day_of_week: day_of_week,
        opens_at: "09:00",
        closes_at: "18:00"
      }
    end
  end
end
