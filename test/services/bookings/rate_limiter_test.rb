require "test_helper"

class Bookings::RateLimiterTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "RateLimiter service test", slug: "rate-limiter-service-test")
    @original_cache = Rails.cache
    @previous_pending_limit = ENV["BOOKINGS_PENDING_RATE_LIMIT"]
    @previous_window = ENV["BOOKINGS_RATE_LIMIT_WINDOW_SECONDS"]
    Bookings::RateLimiter.warned_cache_store_classes.clear
  end

  teardown do
    ENV["BOOKINGS_PENDING_RATE_LIMIT"] = @previous_pending_limit
    ENV["BOOKINGS_RATE_LIMIT_WINDOW_SECONDS"] = @previous_window
    Rails.cache = @original_cache
    Bookings::RateLimiter.warned_cache_store_classes.clear
  end

  test "shared_cache_store? is false for memory store" do
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    assert_not Bookings::RateLimiter.shared_cache_store?
  end

  test "shared_cache_store? is true for non-local cache store" do
    shared_store_class = Class.new(ActiveSupport::Cache::Store)
    Rails.cache = shared_store_class.new

    assert Bookings::RateLimiter.shared_cache_store?
  end

  test "logs cache warning only once per non shared cache store class" do
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ENV["BOOKINGS_PENDING_RATE_LIMIT"] = "10"
    ENV["BOOKINGS_RATE_LIMIT_WINDOW_SECONDS"] = "600"

    logger = Class.new do
      attr_reader :warnings

      def initialize
        @warnings = []
      end

      def warn(message)
        @warnings << message
      end
    end.new
    previous_logger = Rails.logger
    Rails.logger = logger

    begin
      2.times do
        Bookings::RateLimiter.allowed?(
          client: @client,
          ip: "198.51.100.1",
          action: Bookings::RateLimiter::PENDING_ACTION
        )
      end
    ensure
      Rails.logger = previous_logger
    end

    assert_equal 1, logger.warnings.size
    assert_match(/Bookings::RateLimiter is using/, logger.warnings.first)
  end
end
