module ApplicationHelper
  DAY_OF_WEEK_LABELS = {
    0 => "Dimanche",
    1 => "Lundi",
    2 => "Mardi",
    3 => "Mercredi",
    4 => "Jeudi",
    5 => "Vendredi",
    6 => "Samedi"
  }.freeze

  # price_cents: integer stored in DB (e.g. 6000 = 60€). Converts to euros for display.
  def format_price_cents(price_cents)
    euros = price_cents.to_i / 100.0
    number_to_currency(euros, unit: "€", precision: 0)
  end

  def day_of_week_label(raw_day)
    DAY_OF_WEEK_LABELS[raw_day.to_i] || "-"
  end

  def format_time_label(raw_time)
    return "-" if raw_time.blank?

    parsed_time = Time.zone.parse(raw_time.to_s)
    return raw_time.to_s if parsed_time.nil?

    parsed_time.strftime("%H:%M")
  rescue ArgumentError, TypeError
    raw_time.to_s
  end

  def format_datetime_label(raw_datetime)
    return "-" if raw_datetime.blank?

    raw_datetime.in_time_zone.strftime("%d/%m/%Y à %H:%M")
  end

  def format_date_label(raw_datetime)
    return "-" if raw_datetime.blank?

    raw_datetime.in_time_zone.strftime("%d/%m/%Y")
  end
end
