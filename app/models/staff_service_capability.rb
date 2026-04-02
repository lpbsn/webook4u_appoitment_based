class StaffServiceCapability < ApplicationRecord
  belongs_to :staff
  belongs_to :service

  validates :service_id, uniqueness: { scope: :staff_id }
end
