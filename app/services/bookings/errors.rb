# frozen_string_literal: true

module Bookings
  module Errors
    # These codes describe transient booking-flow failures. They are not
    # persisted booking statuses and must not be mapped to `failed`.
    INVALID_SLOT              = :invalid_slot
    SLOT_UNAVAILABLE          = :slot_unavailable
    SLOT_NOT_BOOKABLE         = :slot_not_bookable
    PENDING_CREATION_FAILED   = :pending_creation_failed
    NOT_PENDING               = :not_pending
    SESSION_EXPIRED           = :session_expired
    FORM_INVALID              = :form_invalid
    SLOT_TAKEN_DURING_CONFIRM = :slot_taken_during_confirm

    MESSAGES = {
      INVALID_SLOT => "Le créneau sélectionné est invalide.",
      SLOT_UNAVAILABLE => "Le créneau sélectionné n'est plus disponible.",
      SLOT_NOT_BOOKABLE => "Le créneau sélectionné n'est pas réservable.",
      PENDING_CREATION_FAILED => "Impossible de créer la réservation temporaire.",
      NOT_PENDING => "Cette réservation ne peut plus être confirmée. Veuillez recommencer votre sélection.",
      SESSION_EXPIRED => "Votre session a expiré. Veuillez renouveler votre réservation.",
      FORM_INVALID => "Le formulaire contient des erreurs.",
      SLOT_TAKEN_DURING_CONFIRM => "Le créneau sélectionné vient d'être réservé par un autre utilisateur."
    }.freeze

    SLOT_CONFLICT_CONSTRAINTS = [
      "bookings_confirmed_no_overlapping_intervals_per_staff"
    ].freeze

    def self.message_for(code)
      MESSAGES[code]
    end

    def self.booking_conflict_exception?(error)
      cause = extract_pg_cause(error)
      return false if cause.nil?

      return false unless cause.is_a?(PG::ExclusionViolation) || cause.is_a?(PG::UniqueViolation)

      SLOT_CONFLICT_CONSTRAINTS.include?(extract_constraint_name(cause))
    end

    def self.extract_pg_cause(error)
      return error if error.is_a?(PG::Error)

      error.respond_to?(:cause) ? error.cause : nil
    end
    private_class_method :extract_pg_cause

    def self.extract_constraint_name(pg_error)
      return nil unless pg_error.respond_to?(:result)

      result = pg_error.result
      return nil if result.nil?

      result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end
    private_class_method :extract_constraint_name
  end
end
