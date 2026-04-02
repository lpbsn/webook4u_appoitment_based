class Client < ApplicationRecord
  has_many :client_opening_hours, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :enseignes, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  validate :name_must_not_be_whitespace_only

  private

  def name_must_not_be_whitespace_only
    return unless name.is_a?(String)
    return unless name.strip.empty?

    errors.add(:name, "can't be blank")
  end
end
