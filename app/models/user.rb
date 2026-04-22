class User < ApplicationRecord
  belongs_to :client, optional: true

  has_many :bookings, dependent: :nullify

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, {
    admin: "admin",
    client_user: "client_user",
    booker: "booker"
  }, default: :booker, validate: true

  validates :last_name, presence: true
  validates :first_name, presence: true
  validates :active, inclusion: { in: [ true, false ] }
  validates :email, uniqueness: true
  validates :client, presence: true, if: :client_user?
  validates :client, absence: true, if: :admin?

  def self.find_for_authentication(warden_conditions)
    conditions = warden_conditions.dup
    email = conditions.delete(:email)&.strip&.downcase
    client = Current.auth_client

    return nil if email.blank?

    scope = where(conditions).where(email: email)

    if client.present?
      scope.where(
        "(role = :admin AND client_id IS NULL) OR client_id = :client_id",
        admin: roles.fetch(:admin),
        client_id: client.id
      ).first
    else
      scope.where(
        "(role = :admin AND client_id IS NULL) OR role IN (:booker, :client_user)",
        admin: roles.fetch(:admin),
        booker: roles.fetch(:booker),
        client_user: roles.fetch(:client_user)
      ).first
    end
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    return :inactive_account unless active?

    super
  end
end
