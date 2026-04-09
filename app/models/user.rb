class User < ApplicationRecord
  belongs_to :client

  has_many :bookings, dependent: :nullify

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :last_name, presence: true
  validates :first_name, presence: true
  validates :client, presence: true
  validates :email, uniqueness: { scope: :client_id }

  def self.find_for_authentication(warden_conditions)
    conditions = warden_conditions.dup
    email = conditions.delete(:email)
    client = Current.auth_client

    return nil if client.blank? || email.blank?

    find_by(conditions.merge(email: email, client_id: client.id))
  end
end
