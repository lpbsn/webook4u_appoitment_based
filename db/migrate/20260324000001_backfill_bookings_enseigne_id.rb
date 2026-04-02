class BackfillBookingsEnseigneId < ActiveRecord::Migration[8.1]
  class MigrationClient < ActiveRecord::Base
    self.table_name = "clients"

    has_many :enseignes, class_name: "BackfillBookingsEnseigneId::MigrationEnseigne", foreign_key: :client_id
    has_many :bookings, class_name: "BackfillBookingsEnseigneId::MigrationBooking", foreign_key: :client_id
  end

  class MigrationEnseigne < ActiveRecord::Base
    self.table_name = "enseignes"

    belongs_to :client, class_name: "BackfillBookingsEnseigneId::MigrationClient"
  end

  class MigrationBooking < ActiveRecord::Base
    self.table_name = "bookings"

    belongs_to :client, class_name: "BackfillBookingsEnseigneId::MigrationClient"
  end

  def up
    legacy_client_ids = MigrationBooking.where(enseigne_id: nil).distinct.pluck(:client_id)

    legacy_client_ids.each do |client_id|
      client = MigrationClient.find(client_id)
      legacy_bookings = client.bookings.where(enseigne_id: nil)

      next unless legacy_bookings.exists?

      enseigne = resolve_enseigne_for!(client, legacy_bookings.count)
      legacy_bookings.update_all(enseigne_id: enseigne.id)
    end

    remaining_count = MigrationBooking.where(enseigne_id: nil).count
    return if remaining_count.zero?

    raise ActiveRecord::MigrationError, "Backfill incomplete: #{remaining_count} bookings still have no enseigne_id"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot safely restore legacy bookings without enseigne_id"
  end

  private

  def resolve_enseigne_for!(client, legacy_bookings_count)
    enseignes = client.enseignes.order(:id).to_a

    return client.enseignes.create!(name: client.name, full_address: nil, active: true) if enseignes.empty?
    return enseignes.first if enseignes.one?

    raise ActiveRecord::MigrationError,
          "Ambiguous legacy booking backfill for client ##{client.id} (#{client.slug}): " \
          "#{legacy_bookings_count} bookings without enseigne_id and #{enseignes.count} enseignes. " \
          "Assign bookings manually before retrying."
  end
end
