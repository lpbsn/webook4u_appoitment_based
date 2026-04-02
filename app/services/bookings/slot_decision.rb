# frozen_string_literal: true

module Bookings
  class SlotDecision
    # Single point of truth for booking-slot evaluation.
    #
    # `bookable?` answers the core business question used by both create and
    # confirm flows: is this interval still valid and unblocked for the
    # reservable resource?
    #
    # `matches_schedule_grid?` answers a separate schedule-alignment question
    # used only by create flows: does this start time still align with the
    # theoretical booking grid for that day without regenerating every slot?
    #
    # The slot is evaluated against a reservable Resource abstraction rather
    # than directly against the public booking context. Today this resource is
    # still the whole enseigne; the next target is an explicit staff resource.
    Result = Struct.new(
      :bookable?,
      :error_code,
      :error_message,
      :booking_start_time,
      :booking_end_time,
      :resource,
      :matches_schedule_grid?,
      keyword_init: true
    ) do
      def creatable?
        bookable? && matches_schedule_grid?
      end
    end

    def initialize(client:, service:, booking_start_time:, enseigne:, exclude_booking_id: nil, resource: nil)
      @client = client
      @enseigne = enseigne
      @service = service
      @booking_start_time = booking_start_time
      @exclude_booking_id = exclude_booking_id
      @resource = resource
    end

    def call
      return failure(Errors::INVALID_SLOT, matches_schedule_grid: false) if booking_start_time.nil?

      schedule_grid_match = matches_schedule_grid?
      return failure(Errors::SLOT_UNAVAILABLE, matches_schedule_grid: schedule_grid_match) if blocked_slot?

      success(matches_schedule_grid: schedule_grid_match)
    end

    private

    attr_reader :client, :enseigne, :service, :booking_start_time, :exclude_booking_id

    def booking_end_time
      @booking_end_time ||= booking_start_time + service.duration_minutes.minutes
    end

    def resource
      # Current trivial resolution:
      # public enseigne selection -> one implicit staff/resource for that enseigne.
      # Once multiple staffs exist, this resolution will become an explicit
      # domain step without changing SlotDecision's public contract.
      @resource ||= Resource.for_enseigne(client: client, enseigne: enseigne)
    end

    def matches_schedule_grid?
      return false if booking_start_time.nil?

      opening_intervals.any? do |interval_start, interval_end|
        fits_within_interval?(interval_start, interval_end) &&
          starts_on_interval_grid?(interval_start) &&
          respects_minimum_notice?
      end
    end

    def blocked_slot?
      BlockingBookings.overlapping(
        client: client,
        resource: resource,
        start_time: booking_start_time,
        end_time: booking_end_time,
        exclude_booking_id: exclude_booking_id
      ).exists?
    end

    def opening_intervals
      @opening_intervals ||= ScheduleResolver.new(
        client: client,
        enseigne: enseigne,
        date: booking_start_time.to_date
      ).call
    end

    def fits_within_interval?(interval_start, interval_end)
      booking_start_time >= interval_start && booking_end_time <= interval_end
    end

    def starts_on_interval_grid?(interval_start)
      offset_seconds = booking_start_time.to_i - interval_start.to_i
      return false if offset_seconds.negative?

      (offset_seconds % BookingRules.slot_duration.to_i).zero?
    end

    def respects_minimum_notice?
      booking_start_time >= BookingRules.minimum_bookable_time
    end

    def success(matches_schedule_grid:)
      Result.new(
        bookable?: true,
        error_code: nil,
        error_message: nil,
        booking_start_time: booking_start_time,
        booking_end_time: booking_end_time,
        resource: resource,
        matches_schedule_grid?: matches_schedule_grid
      )
    end

    def failure(code, matches_schedule_grid:)
      Result.new(
        bookable?: false,
        error_code: code,
        error_message: Errors.message_for(code),
        booking_start_time: booking_start_time,
        booking_end_time: booking_start_time.present? ? booking_end_time : nil,
        resource: resource,
        matches_schedule_grid?: matches_schedule_grid
      )
    end
  end
end
