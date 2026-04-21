module BookingLayoutHelper
  def booking_page_classes
    classes = ["booking-page"]
    classes << "booking-page--public-client" if controller_path == "public_clients" && action_name == "show"
    classes.join(" ")
  end

  def booking_card_classes
    classes = ["booking-card"]
    classes << "booking-card--public-client" if controller_path == "public_clients" && action_name == "show"
    classes << "booking-success" if controller_path == "bookings" && action_name == "success"
    classes.join(" ")
  end

  def booking_personal_space_path
    case current_user.role
    when "admin"
      admin_root_path
    when "client_user"
      client_root_path
    else
      user_root_path
    end
  end

  def booking_back_href
    explicit_back_href = content_for?(:booking_back_href) ? content_for(:booking_back_href).to_s.strip : ""
    explicit_back_href.presence || request.referer.presence || "#"
  end
end
