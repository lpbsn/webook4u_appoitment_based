class StaffAvailability < ApplicationRecord
  belongs_to :staff

  validates :day_of_week, presence: true
  validates :opens_at, presence: true
  validates :closes_at, presence: true
end
