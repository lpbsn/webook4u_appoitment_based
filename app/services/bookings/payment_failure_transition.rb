# frozen_string_literal: true

module Bookings
  class PaymentFailureTransition
    Result = Struct.new(:success?, :booking, :error_code, :error_message, keyword_init: true)

    def initialize(booking:, stripe_session_id: nil, stripe_payment_intent: nil)
      @booking = booking
      @stripe_session_id = stripe_session_id
      @stripe_payment_intent = stripe_payment_intent
    end

    def call
      transition = TransitionToFailedFromPayment.evaluate(booking: booking)
      return failure(transition.error_code) unless transition.allowed?

      booking.update!(
        booking_status: :failed,
        stripe_session_id: stripe_session_id.presence || booking.stripe_session_id,
        stripe_payment_intent: stripe_payment_intent.presence || booking.stripe_payment_intent
      )

      success
    rescue ActiveRecord::RecordInvalid
      failure(Errors::FORM_INVALID)
    end

    private

    attr_reader :booking, :stripe_session_id, :stripe_payment_intent

    def success
      Result.new(success?: true, booking: booking, error_code: nil, error_message: nil)
    end

    def failure(code)
      Result.new(
        success?: false,
        booking: booking,
        error_code: code,
        error_message: Errors.message_for(code)
      )
    end
  end
end
