# app/services/bookings/first_available_slot_search.rb
# frozen_string_literal: true

module Bookings
  class FirstAvailableSlotSearch
    def initialize(
      client:,
      enseigne:,
      service:,
      assignment_mode:,
      staff: nil,
      selected_days_of_week:,
      start_time_min:,
      start_time_max:
    )
      @client = client
      @enseigne = enseigne
      @service = service
      @assignment_mode = assignment_mode
      @staff = staff
      @selected_days_of_week = selected_days_of_week
      @start_time_min = start_time_min
      @start_time_max = start_time_max
    end

    def call
      candidate_dates.each do |date|
        next unless selected_day?(date)

        matching_slot = first_matching_slot_for_date(date)
        return matching_slot if matching_slot.present?
      end

      nil
    end

    private

    attr_reader(
      :client,
      :enseigne,
      :service,
      :assignment_mode,
      :staff,
      :selected_days_of_week,
      :start_time_min,
      :start_time_max
    )

    def search_start_time
      BookingRules.minimum_bookable_time
    end

    def search_start_date
      search_start_time.to_date
    end

    def search_end_date
      search_start_date + BookingRules.max_future_days.days
    end

    def candidate_dates
      (search_start_date..search_end_date)
    end

    def selected_day?(date)
      normalized_selected_days_of_week.include?(date.wday)
    end

    def normalized_selected_days_of_week
      @normalized_selected_days_of_week ||= Array(selected_days_of_week)
        .map(&:to_i)
        .uniq
    end

    def first_matching_slot_for_date(date)
      slots_for_date(date).find { |slot| slot_matches_time_range?(slot) }
    end

    def slots_for_date(date)
      case assignment_mode
      when "automatic"
        Bookings::AvailableSlots.new(
          client: client,
          enseigne: enseigne,
          service: service,
          date: date
        ).call
      when "specific_staff"
        return [] if staff.blank?

        Bookings::AvailableSlots.new(
          client: client,
          enseigne: enseigne,
          service: service,
          date: date,
          staff: staff
        ).call
      else
        []
      end
    end

    def slot_matches_time_range?(slot)
      slot_minutes = slot.hour * 60 + slot.min

      return false if start_time_min_minutes.present? && slot_minutes < start_time_min_minutes
      return false if start_time_max_minutes.present? && slot_minutes > start_time_max_minutes

      true
    end

    def start_time_min_minutes
      @start_time_min_minutes ||= parse_time_to_minutes(start_time_min)
    end

    def start_time_max_minutes
      @start_time_max_minutes ||= parse_time_to_minutes(start_time_max)
    end

    def parse_time_to_minutes(value)
      return nil if value.blank?

      hours, minutes = value.split(":").map(&:to_i)
      (hours * 60) + minutes
    end
  end
end
