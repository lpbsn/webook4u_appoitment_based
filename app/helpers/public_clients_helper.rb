module PublicClientsHelper
  def public_client_selected_enseigne_name(selected_enseigne)
    selected_enseigne&.name || "—"
  end

  def public_client_selected_enseigne_address(selected_enseigne)
    selected_enseigne&.full_address.presence || "—"
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
end
