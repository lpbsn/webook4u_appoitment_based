require "test_helper"

class Bookings::ResourceTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client resource", slug: "client-resource")
    @enseigne = @client.enseignes.create!(name: "Enseigne resource")
  end

  test "for_enseigne maps current booking context to a reservable resource" do
    resource = Bookings::Resource.for_enseigne(client: @client, enseigne: @enseigne)

    assert_equal :enseigne, resource.kind
    assert_equal @enseigne.id, resource.identifier
    assert_equal @enseigne.bookings.to_sql, resource.bookings_scope.to_sql
  end

  test "lock_key depends on logical resource identity rather than slot attributes" do
    resource = Bookings::Resource.for_enseigne(client: @client, enseigne: @enseigne)

    assert_equal [ Bookings::Resource::RESOURCE_KIND_ENSEIGNE, @enseigne.id ], resource.lock_key
  end

  test "resource kind namespace already reserves a future staff-specific key space" do
    assert_equal 2, Bookings::Resource::RESOURCE_KIND_STAFF
  end
end
