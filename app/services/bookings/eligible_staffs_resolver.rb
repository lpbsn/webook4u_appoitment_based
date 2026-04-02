# frozen_string_literal: true

module Bookings
  class EligibleStaffsResolver
    def initialize(service:, enseigne:)
      @service = service
      @enseigne = enseigne
    end

    def call
      return Staff.none if service.blank? || enseigne.blank?
      return Staff.none if service.enseigne_id != enseigne.id

      enseigne.staffs
              .where(active: true)
              .joins(:staff_service_capabilities)
              .where(staff_service_capabilities: { service_id: service.id })
              .distinct
              .order(:id)
    end

    private

    attr_reader :service, :enseigne
  end
end
