class Staff < ApplicationRecord
  belongs_to :enseigne

  has_many :staff_availabilities, dependent: :destroy
  has_many :staff_unavailabilities, dependent: :destroy
  has_many :staff_service_capabilities, dependent: :destroy
  has_many :services, through: :staff_service_capabilities
  has_many :bookings, dependent: :nullify

  validates :name, presence: true
end
