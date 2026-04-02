class PurgeExpiredPendingBookingsJob < ActiveJob::Base
  queue_as :default

  def perform
    Bookings::PurgeExpiredPending.call
  end
end
