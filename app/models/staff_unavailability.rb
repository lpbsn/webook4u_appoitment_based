class StaffUnavailability < ApplicationRecord
  belongs_to :staff

  validates :starts_at, presence: true
  validates :ends_at, presence: true
end
