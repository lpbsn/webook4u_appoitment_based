# frozen_string_literal: true

module Bookings
  class RateLimiter
    PENDING_ACTION = :pending_creation
    CONFIRM_ACTION = :confirmation

    DEFAULT_PENDING_LIMIT = 5
    DEFAULT_CONFIRM_LIMIT = 8
    DEFAULT_WINDOW_SECONDS = 10.minutes.to_i
    NON_SHARED_CACHE_STORES = [
      ActiveSupport::Cache::MemoryStore,
      ActiveSupport::Cache::FileStore,
      ActiveSupport::Cache::NullStore
    ].freeze

    def self.allowed?(client:, ip:, action:)
      new(client: client, ip: ip, action: action).allowed?
    end

    def self.fallback_lock
      @fallback_lock ||= Mutex.new
    end

    def self.warning_lock
      @warning_lock ||= Mutex.new
    end

    def self.warned_cache_store_classes
      @warned_cache_store_classes ||= {}
    end

    def self.shared_cache_store?
      NON_SHARED_CACHE_STORES.none? { |store_class| Rails.cache.is_a?(store_class) }
    end

    def initialize(client:, ip:, action:)
      @client = client
      @ip = ip.presence || "unknown"
      @action = action
    end

    def allowed?
      warn_if_non_shared_cache_store
      limit = limit_for_action
      return false if limit <= 0

      current_count <= limit
    end

    private

    attr_reader :client, :ip, :action

    def current_count
      incremented_count = Rails.cache.increment(cache_key, 1, expires_in: window_seconds)
      return incremented_count if incremented_count.present?

      # Fallback for cache stores without atomic increment support.
      self.class.fallback_lock.synchronize do
        existing_count = Rails.cache.read(cache_key).to_i
        updated_count = existing_count + 1
        Rails.cache.write(cache_key, updated_count, expires_in: window_seconds)
        updated_count
      end
    end

    def cache_key
      [ "bookings-rate-limit", client.id, action, ip ].join(":")
    end

    def limit_for_action
      case action
      when PENDING_ACTION
        env_int("BOOKINGS_PENDING_RATE_LIMIT", DEFAULT_PENDING_LIMIT)
      when CONFIRM_ACTION
        env_int("BOOKINGS_CONFIRM_RATE_LIMIT", DEFAULT_CONFIRM_LIMIT)
      else
        0
      end
    end

    def window_seconds
      env_int("BOOKINGS_RATE_LIMIT_WINDOW_SECONDS", DEFAULT_WINDOW_SECONDS)
    end

    def env_int(name, fallback)
      raw_value = ENV[name]
      return fallback if raw_value.blank?

      Integer(raw_value)
    rescue ArgumentError
      fallback
    end

    def warn_if_non_shared_cache_store
      return if self.class.shared_cache_store?

      cache_store_class = Rails.cache.class.name

      self.class.warning_lock.synchronize do
        return if self.class.warned_cache_store_classes[cache_store_class]

        self.class.warned_cache_store_classes[cache_store_class] = true
        Rails.logger.warn(
          "Bookings::RateLimiter is using #{cache_store_class}; " \
          "this cache store is local to a process and does not provide multi-instance protection."
        )
      end
    end
  end
end
