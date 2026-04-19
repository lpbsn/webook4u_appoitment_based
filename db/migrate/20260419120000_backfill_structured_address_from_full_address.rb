class BackfillStructuredAddressFromFullAddress < ActiveRecord::Migration[8.1]
  class MigrationEnseigne < ApplicationRecord
    self.table_name = "enseignes"
  end

  def up
    MigrationEnseigne.where(address: nil).or(MigrationEnseigne.where(postal_code: nil))
                    .or(MigrationEnseigne.where(city: nil))
                    .or(MigrationEnseigne.where(country: nil))
                    .find_each do |enseigne|
      next if enseigne.full_address.blank?

      address, postal_code, city, country = parse_full_address(enseigne.full_address)
      enseigne.update_columns(
        address: enseigne.address.presence || address,
        postal_code: enseigne.postal_code.presence || postal_code,
        city: enseigne.city.presence || city,
        country: enseigne.country.presence || country
      )
    end
  end

  def down
    # No-op: backfill is best-effort for historical test data.
  end

  private

  def parse_full_address(value)
    chunks = value.to_s.split(",").map(&:strip).reject(&:blank?)
    address = chunks[0]
    postal_city = chunks[1].to_s
    country = chunks[2].presence || "France"

    postal_code = nil
    city = nil
    if postal_city.present?
      parts = postal_city.split(/\s+/)
      postal_code = parts.shift
      city = parts.join(" ").presence
    end

    postal_code ||= "00000"
    city ||= "Ville inconnue"

    [ address, postal_code, city, country ]
  end
end
