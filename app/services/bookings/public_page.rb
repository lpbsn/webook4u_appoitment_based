# frozen_string_literal: true

module Bookings
  class PublicPage
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
      date_param:
    )
      @slug = slug
      @enseigne_id = enseigne_id
      @service_id = service_id
      @assignment_mode_param = assignment_mode_param
      @staff_id_param = staff_id_param
      @search_mode_param = search_mode_param
      @selected_start_time_param = selected_start_time_param
      @date_param = date_param
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

      slots =
        if selected_enseigne.present? && selected_service.present? && date.present?
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
        else
          []
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
        slots: slots
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
      :date_param
    )
  end
end
