require "test_helper"

class PurgeExpiredPendingBookingsJobTest < ActiveSupport::TestCase
  test "delegates to the purge service" do
    result = Bookings::PurgeExpiredPending::Result.new(
      deleted_count: 2,
      upsert_attempt_count: 2,
      batch_count: 1,
      cutoff: Time.zone.now
    )
    with_purge_service_result(result) do
      assert_equal result, PurgeExpiredPendingBookingsJob.perform_now
    end
  end

  test "does not fail when there is nothing to delete" do
    result = Bookings::PurgeExpiredPending::Result.new(
      deleted_count: 0,
      upsert_attempt_count: 0,
      batch_count: 0,
      cutoff: Time.zone.now
    )
    with_purge_service_result(result) do
      assert_nothing_raised do
        PurgeExpiredPendingBookingsJob.perform_now
      end
    end
  end

  private

  def with_purge_service_result(result)
    service_class = Bookings::PurgeExpiredPending.singleton_class
    original_call = Bookings::PurgeExpiredPending.method(:call)

    service_class.define_method(:call) do |*_, **_|
      result
    end

    yield
  ensure
    service_class.define_method(:call, original_call)
  end
end
