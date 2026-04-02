# frozen_string_literal: true

require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "valid client saves without errors" do
    client = Client.new(name: "Salon A", slug: "salon-a")
    assert client.valid?
  end

  test "name is required" do
    client = Client.new(name: nil, slug: "salon-b")
    assert_not client.valid?
    assert_includes client.errors[:name], "can't be blank"
  end

  test "name with only spaces is invalid" do
    client = Client.new(name: "   ", slug: "salon-whitespace")

    assert_not client.valid?
    assert_includes client.errors[:name], "can't be blank"
  end

  test "create with whitespace-only name fails at model level with save and save!" do
    client = Client.new(name: "   ", slug: "salon-whitespace-create")

    assert_equal false, client.save
    assert_includes client.errors[:name], "can't be blank"
    assert_raises(ActiveRecord::RecordInvalid) { client.save! }
  end

  test "update to whitespace-only name fails at model level with save and save!" do
    client = Client.create!(name: "Salon Update", slug: "salon-update-name")

    client.name = "   "
    assert_equal false, client.save
    assert_includes client.errors[:name], "can't be blank"
    assert_raises(ActiveRecord::RecordInvalid) { client.save! }
  end

  test "slug is required" do
    client = Client.new(name: "Salon C", slug: nil)
    assert_not client.valid?
    assert_includes client.errors[:slug], "can't be blank"
  end

  test "slug must be unique" do
    Client.create!(name: "Salon D", slug: "slug-dupe")

    duplicate = Client.new(name: "Autre", slug: "slug-dupe")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "database enforces unique slug" do
    timestamp = Time.current

    Client.insert_all!([
      { name: "Salon DB A", slug: "db-slug-dupe", created_at: timestamp, updated_at: timestamp }
    ])

    assert_raises ActiveRecord::RecordNotUnique do
      Client.insert_all!([
        { name: "Salon DB B", slug: "db-slug-dupe", created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "database enforces non null slug" do
    timestamp = Time.current

    assert_raises ActiveRecord::NotNullViolation do
      Client.insert_all!([
        { name: "Salon Sans Slug", slug: nil, created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "database enforces non null name" do
    timestamp = Time.current

    assert_raises ActiveRecord::NotNullViolation do
      Client.insert_all!([
        { name: nil, slug: "client-name-null", created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "database rejects blank name" do
    timestamp = Time.current

    assert_raises ActiveRecord::StatementInvalid do
      Client.insert_all!([
        { name: "", slug: "client-name-blank", created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "database rejects whitespace-only name" do
    timestamp = Time.current

    assert_raises ActiveRecord::StatementInvalid do
      Client.insert_all!([
        { name: "   ", slug: "client-name-space", created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "client does not expose a direct services association" do
    assert_nil Client.reflect_on_association(:services)
  end

  test "destroying client destroys associated services" do
    client = Client.create!(name: "Salon E", slug: "salon-e")
    enseigne = client.enseignes.create!(name: "Enseigne E")
    enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 1500)

    assert_difference "Service.count", -1 do
      client.destroy
    end
  end

  test "destroying client destroys associated enseignes" do
    client = Client.create!(name: "Salon Enseignes", slug: "salon-enseignes")
    client.enseignes.create!(name: "Enseigne A")

    assert_difference "Enseigne.count", -1 do
      client.destroy
    end
  end

  test "destroying client destroys associated bookings" do
    client = Client.create!(name: "Salon F", slug: "salon-f")
    enseigne = client.enseignes.create!(name: "Enseigne F")
    service = enseigne.services.create!(name: "Coupe", duration_minutes: 30, price_cents: 1500)
    staff = enseigne.staffs.create!(name: "Staff client destroy", active: true)
    client.bookings.create!(
      enseigne: enseigne,
      service: service,
      staff: staff,
      booking_start_time: 2.days.from_now.change(hour: 10, min: 0, sec: 0),
      booking_end_time: 2.days.from_now.change(hour: 10, min: 30, sec: 0),
      booking_status: :confirmed,
      customer_first_name: "Jean",
      customer_last_name: "Dupont",
      customer_email: "jean@example.com"
    )

    assert_difference "Booking.count", -1 do
      client.destroy
    end
  end
end
