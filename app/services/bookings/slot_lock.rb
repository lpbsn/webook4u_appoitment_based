# frozen_string_literal: true

module Bookings
  class SlotLock
    SERVICE_ROTATION_NAMESPACE = 3_001
    STAFF_NAMESPACE = 3_002

    def self.with_service_rotation_lock(service:)
      raise ArgumentError, "service is required" if service.blank?

      ActiveRecord::Base.transaction do
        acquire_lock(SERVICE_ROTATION_NAMESPACE, service.id)
        yield
      end
    end

    def self.with_staff_lock(staff:)
      raise ArgumentError, "staff is required" if staff.blank?

      ActiveRecord::Base.transaction do
        acquire_lock(STAFF_NAMESPACE, staff.id)
        yield
      end
    end

    # Expected lock ordering for transaction flows:
    # 1) lock service rotation, 2) lock staff candidate.
    def self.with_service_rotation_then_staff_lock(service:, staff:)
      raise ArgumentError, "service is required" if service.blank?
      raise ArgumentError, "staff is required" if staff.blank?

      ActiveRecord::Base.transaction do
        acquire_lock(SERVICE_ROTATION_NAMESPACE, service.id)
        acquire_lock(STAFF_NAMESPACE, staff.id)
        yield
      end
    end

    def self.acquire_lock(namespace, identifier)
      ActiveRecord::Base.connection.execute(
        "SELECT pg_advisory_xact_lock(#{namespace.to_i}, #{identifier.to_i})"
      )
    end
    private_class_method :acquire_lock
  end
end
