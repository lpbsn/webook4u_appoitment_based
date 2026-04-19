# frozen_string_literal: true

module Bookings
  class PublicPage
    PreciseDateDay = Struct.new(:date, :slots, keyword_init: true)

    Result = Struct.new(
      :client,
      :enseignes,
      :selected_enseigne,
      :services,
      :selected_service,
      :assignment_mode,
      :eligible_staffs,
      :selected_staff,
      :search_mode,
      :selected_start_time,
      :date,
      :slots,
      :precise_date_days,
      :first_available_selected_days_of_week,
      :first_available_start_time_min,
      :first_available_start_time_max,
      :first_available_available_days_of_week,
      :first_available_errors,
      :first_available_slot,
      :first_available_search_performed,
      keyword_init: true
    )

    def initialize(
      slug:,
      enseigne_id:,
      service_id:,
      assignment_mode_param:,
      staff_id_param:,
      search_mode_param: nil,
      selected_start_time_param: nil,
      date_param:,
      first_available_selected_days_of_week_param: nil,
      first_available_start_time_min_param: nil,
      first_available_start_time_max_param: nil
    )
      @slug = slug
      @enseigne_id = enseigne_id
      @service_id = service_id
      @assignment_mode_param = assignment_mode_param
      @staff_id_param = staff_id_param
      @search_mode_param = search_mode_param
      @selected_start_time_param = selected_start_time_param
      @date_param = date_param
      @first_available_selected_days_of_week_param = first_available_selected_days_of_week_param
      @first_available_start_time_min_param = first_available_start_time_min_param
      @first_available_start_time_max_param = first_available_start_time_max_param
    end

    def call
      client = Client.find_by!(slug: slug)
      enseignes = client.enseignes.active.order(:name)

      selected_enseigne = if enseigne_id.present?
        enseignes.find_by(id: enseigne_id)
      elsif enseignes.one?
        enseignes.first
      end

      services = selected_enseigne.present? ? selected_enseigne.services.order(:name) : Service.none

      selected_service =
        selected_enseigne.services.find_by(id: service_id) if selected_enseigne.present? && service_id.present?

      eligible_staffs =
        if selected_enseigne.present? && selected_service.present?
          EligibleStaffsResolver.new(
            service: selected_service,
            enseigne: selected_enseigne
          ).call
        else
          Staff.none
        end

      assignment_mode =
        if selected_service.blank? || eligible_staffs.blank?
          nil
        elsif %w[automatic specific_staff].include?(assignment_mode_param)
          assignment_mode_param
        else
          "automatic"
        end

      selected_staff =
        if assignment_mode == "specific_staff" && staff_id_param.present?
          eligible_staffs.find_by(id: staff_id_param)
        end

      search_mode =
        if assignment_mode.blank?
          nil
        elsif %w[precise_date first_available].include?(search_mode_param)
          search_mode_param
        else
          nil
        end

      selected_start_time = selected_start_time_param.presence

      date =
        if assignment_mode == "automatic" ||
          (assignment_mode == "specific_staff" && selected_staff.present?)
          Input.safe_date(date_param)
        end

      precise_date_days =
        precise_date_days(
          client: client,
          selected_enseigne: selected_enseigne,
          selected_service: selected_service,
          assignment_mode: assignment_mode,
          selected_staff: selected_staff,
          date: date,
          search_mode: search_mode
        )

      slots = date.present? ? precise_date_days.find { |day| day.date == date }&.slots.to_a : []

      first_available_available_days_of_week =
        available_days_of_week(
          enseigne: selected_enseigne,
          assignment_mode: assignment_mode,
          selected_staff: selected_staff,
          eligible_staffs: eligible_staffs
        )

      first_available_selected_days_of_week =
        normalize_selected_days_of_week(first_available_selected_days_of_week_param)

      first_available_start_time_min = first_available_start_time_min_param.presence
      first_available_start_time_max = first_available_start_time_max_param.presence

      first_available_errors =
        first_available_errors(
          search_mode: search_mode,
          selected_days_of_week: first_available_selected_days_of_week,
          start_time_min: first_available_start_time_min,
          start_time_max: first_available_start_time_max
        )

      first_available_search_performed =
        selected_enseigne.present? &&
        selected_service.present? &&
        search_mode == "first_available" &&
        first_available_errors.empty? &&
        first_available_selected_days_of_week.present? &&
        first_available_start_time_min.present? &&
        first_available_start_time_max.present? &&
        (
          assignment_mode == "automatic" ||
          (assignment_mode == "specific_staff" && selected_staff.present?)
        )

      first_available_slot =
        if first_available_search_performed
          Bookings::FirstAvailableSlotSearch.new(
            client: client,
            enseigne: selected_enseigne,
            service: selected_service,
            assignment_mode: assignment_mode,
            staff: selected_staff,
            selected_days_of_week: first_available_selected_days_of_week,
            start_time_min: first_available_start_time_min,
            start_time_max: first_available_start_time_max
          ).call
        end

      Result.new(
        client: client,
        enseignes: enseignes,
        selected_enseigne: selected_enseigne,
        services: services,
        selected_service: selected_service,
        assignment_mode: assignment_mode,
        eligible_staffs: eligible_staffs,
        selected_staff: selected_staff,
        search_mode: search_mode,
        selected_start_time: selected_start_time,
        date: date,
        slots: slots,
        precise_date_days: precise_date_days,
        first_available_selected_days_of_week: first_available_selected_days_of_week,
        first_available_start_time_min: first_available_start_time_min,
        first_available_start_time_max: first_available_start_time_max,
        first_available_available_days_of_week: first_available_available_days_of_week,
        first_available_errors: first_available_errors,
        first_available_slot: first_available_slot,
        first_available_search_performed: first_available_search_performed
      )
    end

    private

    attr_reader(
      :slug,
      :enseigne_id,
      :service_id,
      :assignment_mode_param,
      :staff_id_param,
      :search_mode_param,
      :selected_start_time_param,
      :date_param,
      :first_available_selected_days_of_week_param,
      :first_available_start_time_min_param,
      :first_available_start_time_max_param
    )

    def normalize_selected_days_of_week(raw_value)
      Array(raw_value)
        .reject(&:blank?)
        .map(&:to_i)
        .select { |day| (0..6).include?(day) }
        .uniq
        .sort
    end

    def precise_date_days(client:, selected_enseigne:, selected_service:, assignment_mode:, selected_staff:, date:, search_mode:)
      return [] unless search_mode == "precise_date"
      return [] if selected_enseigne.blank? || selected_service.blank?
      return [] unless assignment_mode == "automatic" || (assignment_mode == "specific_staff" && selected_staff.present?)

      planning_start_date = date || BookingRules.business_today
      max_planning_date = BookingRules.business_today + BookingRules.max_future_days.days

      7.times.filter_map do |day_offset|
        current_date = planning_start_date + day_offset.days
        next if current_date > max_planning_date

        PreciseDateDay.new(
          date: current_date,
          slots: slots_for_precise_date(
            client: client,
            selected_enseigne: selected_enseigne,
            selected_service: selected_service,
            assignment_mode: assignment_mode,
            selected_staff: selected_staff,
            date: current_date
          )
        )
      end
    end

    def slots_for_precise_date(client:, selected_enseigne:, selected_service:, assignment_mode:, selected_staff:, date:)
      if assignment_mode == "automatic"
        AvailableSlots.new(
          client: client,
          enseigne: selected_enseigne,
          service: selected_service,
          date: date
        ).call
      elsif assignment_mode == "specific_staff" && selected_staff.present?
        AvailableSlots.new(
          client: client,
          enseigne: selected_enseigne,
          service: selected_service,
          date: date,
          staff: selected_staff
        ).call
      else
        []
      end
    end

    def available_days_of_week(enseigne:, assignment_mode:, selected_staff:, eligible_staffs:)
      return [] if enseigne.blank?

      enseigne_days = enseigne.enseigne_opening_hours.distinct.pluck(:day_of_week)

      staff_days =
        case assignment_mode
        when "automatic"
          eligible_staffs.flat_map { |staff| staff.staff_availabilities.pluck(:day_of_week) }
        when "specific_staff"
          selected_staff.present? ? selected_staff.staff_availabilities.pluck(:day_of_week) : []
        else
          []
        end

      enseigne_days
        .intersection(staff_days.uniq)
        .sort
    end

    def first_available_errors(search_mode:, selected_days_of_week:, start_time_min:, start_time_max:)
      return {} unless search_mode == "first_available"
      return {} if selected_days_of_week.empty? && start_time_min.blank? && start_time_max.blank?

      errors = {}

      errors[:selected_days_of_week] = "Sélectionnez au moins un jour." if selected_days_of_week.empty?
      errors[:start_time_min] = "L'heure de début minimale est obligatoire." if start_time_min.blank?
      errors[:start_time_max] = "L'heure de début maximale est obligatoire." if start_time_max.blank?

      if start_time_min.present? && start_time_max.present? && start_time_min > start_time_max
        errors[:start_time_range] = "L'heure de début minimale doit être inférieure ou égale à l'heure de début maximale."
      end

      errors
    end
  end
end
