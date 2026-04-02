module ApplicationHelper
  # price_cents: integer stored in DB (e.g. 6000 = 60€). Converts to euros for display.
  def format_price_cents(price_cents)
    euros = price_cents.to_i / 100.0
    number_to_currency(euros, unit: "€", precision: 0)
  end
end
