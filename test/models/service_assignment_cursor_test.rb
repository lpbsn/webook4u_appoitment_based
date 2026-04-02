require "test_helper"

class ServiceAssignmentCursorTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client cursor", slug: "client-cursor")
    @enseigne = @client.enseignes.create!(name: "Enseigne cursor")
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
end
