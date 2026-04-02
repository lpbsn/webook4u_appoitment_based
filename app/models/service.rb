class Service < ApplicationRecord
  belongs_to :enseigne
  has_one :client, through: :enseigne
  has_many :bookings, dependent: :destroy
  has_many :staff_service_capabilities, dependent: :destroy
  has_many :staffs, through: :staff_service_capabilities
  has_one :service_assignment_cursor, dependent: :destroy

  validates :name, presence: true
  validates :duration_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
