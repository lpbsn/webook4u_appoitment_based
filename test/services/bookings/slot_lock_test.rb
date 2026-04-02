require "test_helper"

class Bookings::SlotLockTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client lock", slug: "client-lock")
    @enseigne = @client.enseignes.create!(name: "Enseigne lock")
    @service = @enseigne.services.create!(name: "Service lock", duration_minutes: 30, price_cents: 2500)
    @staff = @enseigne.staffs.create!(name: "Staff lock", active: true)
  end

  test "locks provided resource lock key for transitional main lock" do
    resource = Bookings::Resource.for_enseigne(client: @client, enseigne: @enseigne)
    calls = capture_acquire_lock_calls do
      Bookings::SlotLock.with_resource_lock(resource: resource) { :ok }
    end

    assert_equal [ resource.lock_key ], calls
  end

  test "locks service rotation namespace with service id" do
    calls = capture_acquire_lock_calls do
      Bookings::SlotLock.with_service_rotation_lock(service: @service) { :ok }
    end

    assert_equal [ [ Bookings::SlotLock::SERVICE_ROTATION_NAMESPACE, @service.id ] ], calls
  end

  test "locks staff namespace with staff id" do
    calls = capture_acquire_lock_calls do
      Bookings::SlotLock.with_staff_lock(staff: @staff) { :ok }
    end

    assert_equal [ [ Bookings::SlotLock::STAFF_NAMESPACE, @staff.id ] ], calls
  end

  test "locks service rotation before staff in combined primitive" do
    calls = capture_acquire_lock_calls do
      Bookings::SlotLock.with_service_rotation_then_staff_lock(service: @service, staff: @staff) { :ok }
    end

    assert_equal [
      [ Bookings::SlotLock::SERVICE_ROTATION_NAMESPACE, @service.id ],
      [ Bookings::SlotLock::STAFF_NAMESPACE, @staff.id ]
    ], calls
  end

  test "raises when required arguments are missing" do
    assert_raises(ArgumentError) do
      Bookings::SlotLock.with_resource_lock(resource: nil) { :ok }
    end

    assert_raises(ArgumentError) do
      Bookings::SlotLock.with_service_rotation_lock(service: nil) { :ok }
    end

    assert_raises(ArgumentError) do
      Bookings::SlotLock.with_staff_lock(staff: nil) { :ok }
    end

    assert_raises(ArgumentError) do
      Bookings::SlotLock.with_service_rotation_then_staff_lock(service: @service, staff: nil) { :ok }
    end
  end

  private

  def capture_acquire_lock_calls
    calls = []
    slot_lock_singleton = class << Bookings::SlotLock; self; end
    slot_lock_singleton.alias_method :acquire_lock_without_slot_lock_test, :acquire_lock
    slot_lock_singleton.define_method(:acquire_lock) do |namespace, identifier|
      calls << [ namespace, identifier ]
    end

    yield
    calls
  ensure
    slot_lock_singleton.alias_method :acquire_lock, :acquire_lock_without_slot_lock_test
    slot_lock_singleton.remove_method :acquire_lock_without_slot_lock_test
    slot_lock_singleton.send(:private, :acquire_lock)
  end
end
