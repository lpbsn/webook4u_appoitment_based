require "test_helper"

class ServiceAssignmentCursorTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client cursor", slug: "client-cursor")
    @enseigne = @client.enseignes.create!(name: "Enseigne cursor")
    @other_enseigne = @client.enseignes.create!(name: "Other enseigne")
    @service = @enseigne.services.create!(name: "Coloration", duration_minutes: 45, price_cents: 5000)
  end

  test "service exposes a dedicated assignment cursor entity" do
    cursor = ServiceAssignmentCursor.create!(service: @service)

    assert_equal cursor, @service.reload.service_assignment_cursor
    assert_equal @service, cursor.service
  end

  test "a service cannot have multiple cursors" do
    ServiceAssignmentCursor.create!(service: @service)

    assert_raises ActiveRecord::RecordNotUnique do
      ServiceAssignmentCursor.insert_all!([
        { service_id: @service.id, created_at: Time.current, updated_at: Time.current }
      ])
    end
  end

  test "orders eligible staffs by staff id asc and excludes inactive or incompatible staffs" do
    eligible_low_id = @enseigne.staffs.create!(name: "Eligible low", active: true)
    inactive_staff = @enseigne.staffs.create!(name: "Inactive", active: false)
    eligible_high_id = @enseigne.staffs.create!(name: "Eligible high", active: true)
    @enseigne.staffs.create!(name: "No capability", active: true)
    other_enseigne_staff = @other_enseigne.staffs.create!(name: "Other enseigne", active: true)

    StaffServiceCapability.create!(staff: eligible_high_id, service: @service)
    StaffServiceCapability.create!(staff: eligible_low_id, service: @service)
    StaffServiceCapability.create!(staff: inactive_staff, service: @service)
    StaffServiceCapability.create!(staff: other_enseigne_staff, service: @service)

    cursor = ServiceAssignmentCursor.create!(service: @service)

    assert_equal [ eligible_low_id.id, eligible_high_id.id ], cursor.ordered_eligible_staffs.pluck(:id)
  end

  test "starts rotation from first eligible staff when last_confirmed_staff_id is nil" do
    first_staff = @enseigne.staffs.create!(name: "First", active: true)
    second_staff = @enseigne.staffs.create!(name: "Second", active: true)
    StaffServiceCapability.create!(staff: first_staff, service: @service)
    StaffServiceCapability.create!(staff: second_staff, service: @service)

    cursor = ServiceAssignmentCursor.create!(service: @service, last_confirmed_staff: nil)

    assert_equal [ first_staff.id, second_staff.id ], cursor.eligible_staffs_in_rotation_order.map(&:id)
    assert_equal first_staff.id, cursor.next_eligible_staff&.id
  end

  test "rotates from the next eligible staff after last confirmed with wrap around" do
    first_staff = @enseigne.staffs.create!(name: "First", active: true)
    second_staff = @enseigne.staffs.create!(name: "Second", active: true)
    StaffServiceCapability.create!(staff: first_staff, service: @service)
    StaffServiceCapability.create!(staff: second_staff, service: @service)

    cursor = ServiceAssignmentCursor.create!(service: @service, last_confirmed_staff: second_staff)

    assert_equal [ first_staff.id, second_staff.id ], cursor.eligible_staffs_in_rotation_order.map(&:id)
    assert_equal first_staff.id, cursor.next_eligible_staff&.id
  end

  test "restarts from first eligible after a non eligible cursor staff id with wrap around" do
    first_staff = @enseigne.staffs.create!(name: "First", active: true)
    ineligible_cursor_staff = @enseigne.staffs.create!(name: "Inactive cursor", active: false)
    second_staff = @enseigne.staffs.create!(name: "Second", active: true)
    StaffServiceCapability.create!(staff: first_staff, service: @service)
    StaffServiceCapability.create!(staff: ineligible_cursor_staff, service: @service)
    StaffServiceCapability.create!(staff: second_staff, service: @service)

    cursor = ServiceAssignmentCursor.create!(service: @service, last_confirmed_staff: ineligible_cursor_staff)

    assert_equal [ second_staff.id, first_staff.id ], cursor.eligible_staffs_in_rotation_order.map(&:id)
    assert_equal second_staff.id, cursor.next_eligible_staff&.id
  end

  test "returns no candidate when service has no eligible staff" do
    cursor = ServiceAssignmentCursor.create!(service: @service)

    assert_equal [], cursor.eligible_staffs_in_rotation_order
    assert_nil cursor.next_eligible_staff
  end
end
