class AddStatusBasedRequiredFieldChecksToBookings < ActiveRecord::Migration[8.1]
  class Booking < ApplicationRecord
    self.table_name = "bookings"
  end

  def up
    sanitize_non_conforming_rows!

    add_check_constraint :bookings,
                         "(booking_status <> 'pending') OR booking_expires_at IS NOT NULL",
                         name: "bookings_pending_requires_booking_expires_at"
    add_check_constraint :bookings,
                         "(booking_status <> 'pending') OR NULLIF(BTRIM(pending_access_token), '') IS NOT NULL",
                         name: "bookings_pending_requires_pending_access_token"
    add_check_constraint :bookings,
                         "(booking_status <> 'confirmed') OR NULLIF(BTRIM(customer_first_name), '') IS NOT NULL",
                         name: "bookings_confirmed_requires_customer_first_name"
    add_check_constraint :bookings,
                         "(booking_status <> 'confirmed') OR NULLIF(BTRIM(customer_last_name), '') IS NOT NULL",
                         name: "bookings_confirmed_requires_customer_last_name"
    add_check_constraint :bookings,
                         "(booking_status <> 'confirmed') OR NULLIF(BTRIM(customer_email), '') IS NOT NULL",
                         name: "bookings_confirmed_requires_customer_email"
    add_check_constraint :bookings,
                         "(booking_status <> 'confirmed') OR NULLIF(BTRIM(confirmation_token), '') IS NOT NULL",
                         name: "bookings_confirmed_requires_confirmation_token"
  end

  def down
    remove_check_constraint :bookings, name: "bookings_confirmed_requires_confirmation_token"
    remove_check_constraint :bookings, name: "bookings_confirmed_requires_customer_email"
    remove_check_constraint :bookings, name: "bookings_confirmed_requires_customer_last_name"
    remove_check_constraint :bookings, name: "bookings_confirmed_requires_customer_first_name"
    remove_check_constraint :bookings, name: "bookings_pending_requires_pending_access_token"
    remove_check_constraint :bookings, name: "bookings_pending_requires_booking_expires_at"
  end

  private

  def sanitize_non_conforming_rows!
    ensure_no_incomplete_confirmed_bookings!

    execute <<~SQL.squish
      UPDATE bookings
      SET booking_expires_at = COALESCE(created_at, CURRENT_TIMESTAMP) + INTERVAL '5 minutes'
      WHERE booking_status = 'pending' AND booking_expires_at IS NULL
    SQL

    backfill_pending_access_tokens!
  end

  def ensure_no_incomplete_confirmed_bookings!
    counts = execute(<<~SQL.squish).first
      SELECT
        COUNT(*) FILTER (WHERE booking_status = 'confirmed' AND NULLIF(BTRIM(customer_first_name), '') IS NULL) AS missing_first_name_count,
        COUNT(*) FILTER (WHERE booking_status = 'confirmed' AND NULLIF(BTRIM(customer_last_name), '') IS NULL) AS missing_last_name_count,
        COUNT(*) FILTER (WHERE booking_status = 'confirmed' AND NULLIF(BTRIM(customer_email), '') IS NULL) AS missing_email_count,
        COUNT(*) FILTER (WHERE booking_status = 'confirmed' AND NULLIF(BTRIM(confirmation_token), '') IS NULL) AS missing_confirmation_token_count,
        COUNT(*) FILTER (
          WHERE booking_status = 'confirmed' AND (
            NULLIF(BTRIM(customer_first_name), '') IS NULL OR
            NULLIF(BTRIM(customer_last_name), '') IS NULL OR
            NULLIF(BTRIM(customer_email), '') IS NULL OR
            NULLIF(BTRIM(confirmation_token), '') IS NULL
          )
        ) AS total_incomplete_count
      FROM bookings
    SQL

    total = counts["total_incomplete_count"].to_i
    return if total.zero?

    sample_ids = execute(<<~SQL.squish).map { |row| row["id"] }
      SELECT id
      FROM bookings
      WHERE booking_status = 'confirmed' AND (
        NULLIF(BTRIM(customer_first_name), '') IS NULL OR
        NULLIF(BTRIM(customer_last_name), '') IS NULL OR
        NULLIF(BTRIM(customer_email), '') IS NULL OR
        NULLIF(BTRIM(confirmation_token), '') IS NULL
      )
      ORDER BY id
      LIMIT 20
    SQL

    raise <<~MESSAGE.squish
      Cannot migrate bookings status constraints: found #{total} incomplete confirmed booking(s).
      missing_first_name=#{counts["missing_first_name_count"]},
      missing_last_name=#{counts["missing_last_name_count"]},
      missing_email=#{counts["missing_email_count"]},
      missing_confirmation_token=#{counts["missing_confirmation_token_count"]}.
      Sample booking ids: #{sample_ids.join(", ")}.
      No synthetic customer data was written; clean these rows via a dedicated remediation before rerunning migration.
    MESSAGE
  end

  def backfill_pending_access_tokens!
    Booking.reset_column_information

    Booking.where("booking_status = 'pending' AND NULLIF(BTRIM(pending_access_token), '') IS NULL").find_each do |booking|
      booking.update_columns(pending_access_token: unique_pending_access_token)
    end
  end

  def unique_pending_access_token
    loop do
      token = SecureRandom.urlsafe_base64(24)
      break token unless Booking.exists?(pending_access_token: token)
    end
  end
end
