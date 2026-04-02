require "test_helper"

class Bookings::EligibleStaffsResolverTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client resolver", slug: "client-resolver")
    @enseigne = @client.enseignes.create!(name: "Enseigne principale")
    @other_enseigne = @client.enseignes.create!(name: "Enseigne secondaire")

    @service = @enseigne.services.create!(
      name: "Coupe",
      duration_minutes: 30,
      price_cents: 2500
    )
  end

  test "returns only active staffs with explicit capability in the selected enseigne" do
    eligible_staff = @enseigne.staffs.create!(name: "Eligible", active: true)
    inactive_staff = @enseigne.staffs.create!(name: "Inactive", active: false)
    @enseigne.staffs.create!(name: "No capability", active: true)
    other_enseigne_staff = @other_enseigne.staffs.create!(name: "Other enseigne", active: true)

    StaffServiceCapability.create!(staff: eligible_staff, service: @service)
    StaffServiceCapability.create!(staff: inactive_staff, service: @service)
    StaffServiceCapability.create!(staff: other_enseigne_staff, service: @service)

    result = Bookings::EligibleStaffsResolver.new(service: @service, enseigne: @enseigne).call

    assert_equal [ eligible_staff.id ], result.pluck(:id)
  end

  test "returns no staff when service and enseigne do not match" do
    cross_enseigne_staff = @other_enseigne.staffs.create!(name: "Cross enseigne", active: true)
    StaffServiceCapability.create!(staff: cross_enseigne_staff, service: @service)

    result = Bookings::EligibleStaffsResolver.new(service: @service, enseigne: @other_enseigne).call

    assert_equal [], result.to_a
  end
end
