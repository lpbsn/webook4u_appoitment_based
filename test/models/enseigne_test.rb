require "test_helper"

class EnseigneTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client enseigne", slug: "client-enseigne")
  end

  test "valid enseigne saves without errors" do
    enseigne = Enseigne.new(
      client: @client,
      name: "Enseigne A",
      address: "1 rue de Paris",
      postal_code: "75001",
      city: "Paris",
      country: "France"
    )

    assert enseigne.valid?
  end

  test "name is required" do
    enseigne = Enseigne.new(client: @client, name: nil)

    assert_not enseigne.valid?
    assert_includes enseigne.errors[:name], "doit être renseigné"
  end

  test "enseigne must belong to a client" do
    enseigne = Enseigne.new(client: nil, name: "Enseigne A")

    assert_not enseigne.valid?
  end

  test "formatted_address uses structured fields" do
    enseigne = Enseigne.new(
      address: "10 rue de Paris",
      postal_code: "75001",
      city: "Paris"
    )

    assert_equal "10 rue de Paris, 75001 Paris", enseigne.formatted_address
  end

  test "formatted_address omits missing chunks without extra separators" do
    assert_equal "10 rue de Paris", Enseigne.new(address: "10 rue de Paris").formatted_address
    assert_equal "75001 Paris", Enseigne.new(postal_code: "75001", city: "Paris").formatted_address
    assert_equal "Paris", Enseigne.new(city: "Paris").formatted_address
  end

  test "destroying enseigne with bookings raises a restriction error" do
    enseigne = @client.enseignes.create!(name: "Enseigne A")
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 2500)
    staff = enseigne.staffs.create!(name: "Staff enseigne destroy", active: true)
    @client.bookings.create!(
      service: service,
      enseigne: enseigne,
      staff: staff,
      booking_start_time: 2.days.from_now.change(hour: 10, min: 0, sec: 0),
      booking_end_time: 2.days.from_now.change(hour: 10, min: 30, sec: 0),
      booking_status: :confirmed,
      customer_first_name: "Jean",
      customer_last_name: "Dupont",
      customer_email: "jean@example.com"
    )

    assert_raises ActiveRecord::DeleteRestrictionError do
      enseigne.destroy
    end
  end
end
