module PublicClientsHelper
  PUBLIC_FLOW_PARAM_KEYS = %i[
    enseigne_id
    service_id
    assignment_mode
    staff_id
    search_mode
    date
    selected_start_time
    selected_days_of_week
    start_time_min
    start_time_max
  ].freeze

  def public_flow_params(source = {}, overrides = {}, compact: true)
    flow_params = extract_public_flow_params(source).merge(extract_public_flow_params(overrides))
    return flow_params unless compact

    flow_params.reject { |key, value| public_flow_blank_value?(key, value) }
  end

  def public_flow_hidden_fields(source = {}, overrides = {}, compact: true)
    public_flow_params(source, overrides, compact: compact).flat_map do |key, value|
      if key == :selected_days_of_week
        Array(value).reject(&:blank?).map { |day| { name: "selected_days_of_week[]", value: day } }
      else
        [{ name: key, value: value }]
      end
    end
  end

  def public_client_selected_enseigne_name(selected_enseigne)
    selected_enseigne&.name || "—"
  end

  def public_client_selected_enseigne_address(selected_enseigne)
    selected_enseigne&.formatted_address.presence || "—"
  end

  def public_client_selected_service_name(selected_service)
    selected_service&.name || "—"
  end

  def public_client_selected_date(date)
    date.present? ? date.strftime("%d/%m/%Y") : "—"
  end

  def public_client_formatted_date(date)
    date.strftime("%d/%m/%Y")
  end

  def public_client_service_price(service)
    format_price_cents(service.price_cents)
  end

  def public_client_slot_label(slot_time)
    slot_time.strftime("%H:%M")
  end

  def public_client_assignment_label(assignment_mode, selected_staff)
    if assignment_mode == "automatic"
      "Tous"
    elsif assignment_mode == "specific_staff" && selected_staff.present?
      selected_staff.name
    end
  end

  def public_client_search_mode_label(search_mode)
    case search_mode
    when "precise_date"
      "Date précise"
    when "first_available"
      "Premier créneau disponible"
    end
  end

  def public_client_summary_date(search_mode:, date:, selected_start_time:, first_available_slot:)
    slot_time =
      if selected_start_time.present?
        Time.zone.parse(selected_start_time.to_s)
      elsif search_mode == "first_available" && first_available_slot.present?
        Time.zone.parse(first_available_slot.to_s)
      end

    target_date = slot_time&.to_date || date
    target_date.present? ? target_date.strftime("%d/%m/%Y") : "—"
  end

  def public_client_summary_slot(search_mode:, selected_start_time:, first_available_slot:)
    slot_time =
      if selected_start_time.present?
        Time.zone.parse(selected_start_time.to_s)
      elsif search_mode == "first_available" && first_available_slot.present?
        Time.zone.parse(first_available_slot.to_s)
      end

    slot_time.present? ? slot_time.strftime("%H:%M") : "—"
  end

  private

  def extract_public_flow_params(source)
    source_hash =
      case source
      when ActionController::Parameters
        source.to_unsafe_h
      when Hash
        source
      when nil
        {}
      else
        source.respond_to?(:to_h) ? source.to_h : {}
      end

    PUBLIC_FLOW_PARAM_KEYS.each_with_object({}) do |key, result|
      if source_hash.key?(key)
        result[key] = source_hash[key]
      elsif source_hash.key?(key.to_s)
        result[key] = source_hash[key.to_s]
      end
    end
  end

  def public_flow_blank_value?(key, value)
    return Array(value).reject(&:blank?).empty? if key == :selected_days_of_week

    value.blank?
  end
end
