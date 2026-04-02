# frozen_string_literal: true

module Bookings
  class PublicPage
    Result = Struct.new(
      :client,
      :enseignes,
      :selected_enseigne,
      :services,
      :selected_service,
      :date,
      :slots,
      keyword_init: true
    )

    def initialize(slug:, enseigne_id:, service_id:, date_param:)
      @slug = slug
      @enseigne_id = enseigne_id
      @service_id = service_id
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

      selected_service = selected_enseigne.services.find_by(id: service_id) if selected_enseigne.present? && service_id.present?

      date = Input.safe_date(date_param)

      slots = if selected_enseigne.present? && selected_service.present? && date.present?
        # Public page exposes the visible UX grid only. Transactional flows
        # revalidate reservability through SlotDecision.
        AvailableSlots.new(client: client, enseigne: selected_enseigne, service: selected_service, date: date).call
      else
        []
      end

      Result.new(
        client: client,
        enseignes: enseignes,
        selected_enseigne: selected_enseigne,
        services: services,
        selected_service: selected_service,
        date: date,
        slots: slots
      )
    end

    private

    attr_reader :slug, :enseigne_id, :service_id, :date_param
  end
end
