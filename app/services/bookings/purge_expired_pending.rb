# frozen_string_literal: true

module Bookings
  class PurgeExpiredPending
    DEFAULT_BATCH_SIZE = 100
    Result = Struct.new(:deleted_count, :upsert_attempt_count, :batch_count, :cutoff, keyword_init: true)

    def self.call(cutoff: Time.zone.now, batch_size: DEFAULT_BATCH_SIZE)
      new(cutoff: cutoff, batch_size: batch_size).call
    end

    def initialize(cutoff:, batch_size:)
      @cutoff = cutoff
      @batch_size = batch_size
    end

    def call
      deleted_count = 0
      upsert_attempt_count = 0
      batch_count = 0

      expired_pending_scope.in_batches(of: batch_size) do |relation|
        rows = relation
               .select(:id, :client_id, :enseigne_id, :service_id, :booking_start_time, :booking_expires_at, :pending_access_token)
               .to_a

        next if rows.empty?

        batch_count += 1
        Booking.transaction do
          deleted_count += Booking.where(id: rows.map(&:id)).delete_all
          upsert_attempt_count += persist_expired_links!(rows)
        end
      end

      Result.new(
        deleted_count: deleted_count,
        upsert_attempt_count: upsert_attempt_count,
        batch_count: batch_count,
        cutoff: cutoff
      )
    end

    private

    attr_reader :cutoff, :batch_size

    def expired_pending_scope
      Booking.pending.where("booking_expires_at < ?", cutoff)
    end

    def persist_expired_links!(rows)
      now = Time.zone.now

      ExpiredBookingLink.upsert_all(
        rows.map do |row|
          {
            client_id: row.client_id,
            pending_access_token: row.pending_access_token,
            enseigne_id: row.enseigne_id,
            service_id: row.service_id,
            booking_date: row.booking_start_time.to_date,
            expired_at: row.booking_expires_at,
            created_at: now,
            updated_at: now
          }
        end,
        unique_by: :index_expired_booking_links_on_pending_access_token
      )

      rows.size
    end
  end
end
