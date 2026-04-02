class Booking < ApplicationRecord
  # Current domain shape:
  # - enseigne is still the visible booking context
  # - the reservable capacity is still implicit: one staff/resource per enseigne
  #
  # Future target:
  # - bookings will also reference an explicit staff-backed reservable resource
  # - overlap protection and locking will move from enseigne-level to staff-level
  before_validation :ensure_pending_access_token
  before_validation :ensure_confirmation_token

  # =========================================================
  # ASSOCIATIONS
  # =========================================================
  belongs_to :client
  belongs_to :enseigne
  belongs_to :service
  # Staff stays optional at association level for transitional pending/failed
  # states, but confirmed bookings must carry an explicit staff.
  belongs_to :staff, optional: true

  # =========================================================
  # ENUM MÉTIER
  # =========================================================
  # Lifecycle boundary:
  # - pending: temporary hold before finalization
  # - confirmed: reservation finalized successfully
  # - failed: reserved for payment-flow failure only
  enum :booking_status, {
    pending: "pending",
    confirmed: "confirmed",
    failed: "failed"
  }

  # =========================================================
  # VALIDATIONS GÉNÉRALES
  # =========================================================
  validates :booking_start_time, presence: true
  validates :booking_end_time, presence: true
  validates :booking_status, presence: true

  # =========================================================
  # VALIDATIONS CONDITIONNELLES
  # =========================================================
  validates :booking_expires_at, presence: true, if: :pending?
  validates :pending_access_token, presence: true, uniqueness: true, if: :pending?
  validate :pending_access_token_not_reused_from_expired_links, if: :pending?

  validates :customer_first_name, presence: true, if: :confirmed?
  validates :customer_last_name, presence: true, if: :confirmed?
  validates :customer_email, presence: true, if: :confirmed?
  validates :confirmation_token, presence: true, uniqueness: true, if: :confirmed?
  validates :staff, presence: true, if: :confirmed?

  validates :customer_email,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            if: :confirmed?

  # =========================================================
  # VALIDATIONS MÉTIER
  # =========================================================
  validate :booking_end_time_after_booking_start_time
  validate :enseigne_belongs_to_client
  validate :service_belongs_to_enseigne
  validate :staff_belongs_to_enseigne

  # =========================================================
  # SCOPES
  # =========================================================
  scope :active_pending, -> { pending.where("booking_expires_at > ?", Time.zone.now) }
  scope :blocking_slot, -> { confirmed.or(active_pending) }

  # =========================================================
  # MÉTHODES MÉTIER
  # =========================================================
  def expired?
    BookingRules.booking_expired?(self)
  end

  def terminal?
    confirmed? || failed?
  end

  def customer_full_name
    [ customer_first_name, customer_last_name ].compact.join(" ")
  end

  private

  def booking_end_time_after_booking_start_time
    return if booking_start_time.blank? || booking_end_time.blank?
    return if booking_end_time > booking_start_time

    errors.add(:booking_end_time, "must be after booking_start_time")
  end

  def enseigne_belongs_to_client
    return if client.blank? || enseigne.blank?
    return if enseigne.client_id == client_id

    errors.add(:enseigne, "must belong to the same client")
  end

  def service_belongs_to_enseigne
    return if service.blank? || enseigne.blank?
    return if service.enseigne_id == enseigne_id

    errors.add(:service, "must belong to the same enseigne")
  end

  def staff_belongs_to_enseigne
    return if staff.blank? || enseigne.blank?
    return if staff.enseigne_id == enseigne_id

    errors.add(:staff, "must belong to the same enseigne")
  end

  def ensure_pending_access_token
    return unless pending?
    return if pending_access_token.present?

    self.pending_access_token = generate_pending_access_token
  end

  def ensure_confirmation_token
    return unless confirmed?
    return if confirmation_token.present?

    self.confirmation_token = generate_confirmation_token
  end

  def generate_pending_access_token
    loop do
      token = SecureRandom.urlsafe_base64(24)
      break token unless pending_access_token_taken_globally?(token)
    end
  end

  def generate_confirmation_token
    loop do
      token = SecureRandom.uuid
      break token unless self.class.exists?(confirmation_token: token)
    end
  end

  def pending_access_token_not_reused_from_expired_links
    return if pending_access_token.blank?
    return unless ExpiredBookingLink.exists?(pending_access_token: pending_access_token)

    errors.add(:pending_access_token, :taken)
  end

  def pending_access_token_taken_globally?(token)
    self.class.exists?(pending_access_token: token) || ExpiredBookingLink.exists?(pending_access_token: token)
  end
end
