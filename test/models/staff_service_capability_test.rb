require "test_helper"

class StaffServiceCapabilityTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client capability", slug: "client-capability")
    @enseigne = @client.enseignes.create!(name: "Enseigne capability")
    @service = @enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)
    @staff = @enseigne.staffs.create!(name: "Staff Capability")
  end

  test "service has no implicit capability without join entity" do
    assert_empty @service.staffs
  end

  test "capability explicitly links staff and service" do
    capability = StaffServiceCapability.create!(staff: @staff, service: @service)

    assert_equal [ @staff ], @service.reload.staffs.to_a
    assert_equal [ @service ], @staff.reload.services.to_a
    assert_equal capability, @staff.staff_service_capabilities.first
  end

  test "duplicate capability is rejected" do
    StaffServiceCapability.create!(staff: @staff, service: @service)
    duplicate = StaffServiceCapability.new(staff: @staff, service: @service)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:service_id], "has already been taken"
  end
end
