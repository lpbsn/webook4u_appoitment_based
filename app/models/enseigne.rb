class Enseigne < ApplicationRecord
  belongs_to :client
  has_many :bookings, dependent: :restrict_with_exception
  has_many :services, dependent: :destroy
  has_many :enseigne_opening_hours, dependent: :destroy
  has_many :staffs, dependent: :destroy

  scope :active, -> { where(active: true) }

  validates :name, presence: true

  def formatted_address
    street = address.to_s.strip.presence
    postal_city = [ postal_code.to_s.strip.presence, city.to_s.strip.presence ].compact.join(" ").presence

    [ street, postal_city ].compact.join(", ").presence
  end
end
