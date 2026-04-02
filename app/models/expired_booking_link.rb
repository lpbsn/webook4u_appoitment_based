class ExpiredBookingLink < ApplicationRecord
  belongs_to :client

  validates :pending_access_token, presence: true
  validates :booking_date, presence: true
  validates :expired_at, presence: true
  validates :pending_access_token, uniqueness: true
  validate :pending_access_token_not_reused_from_bookings

  private

  def pending_access_token_not_reused_from_bookings
    return if pending_access_token.blank?
    return unless Booking.exists?(pending_access_token: pending_access_token)

    errors.add(:pending_access_token, :taken)
  end
end
