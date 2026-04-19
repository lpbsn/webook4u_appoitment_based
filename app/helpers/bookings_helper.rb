module BookingsHelper
  def booking_customer_name(booking)
    booking.customer_full_name
  end

  def booking_enseigne_name(booking)
    booking.enseigne.name
  end

  def booking_enseigne_address(booking)
    booking.enseigne.formatted_address.presence || "—"
  end

  def booking_formatted_slot(booking)
    booking.booking_start_time.strftime("%d/%m/%Y à %H:%M")
  end

  def booking_masked_customer_email(booking)
    email = booking.customer_email.to_s
    local_part, domain = email.split("@", 2)
    return "—" if local_part.blank? || domain.blank?

    visible_prefix = local_part[0]
    masked_tail = "*" * [ local_part.length - 1, 0 ].max
    "#{visible_prefix}#{masked_tail}@#{domain}"
  end
end
