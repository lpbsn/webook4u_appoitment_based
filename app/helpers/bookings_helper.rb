module BookingsHelper
  def booking_customer_name(booking)
    booking.customer_full_name
  end

  def booking_enseigne_name(booking)
    booking.enseigne.name
  end

  def booking_enseigne_address(booking)
    booking.enseigne.full_address.presence || "—"
  end

  def booking_formatted_slot(booking)
    booking.booking_start_time.strftime("%d/%m/%Y à %H:%M")
  end
end
