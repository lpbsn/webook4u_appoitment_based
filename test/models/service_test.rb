# frozen_string_literal: true

require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Salon Test", slug: "salon-test-svc")
    @enseigne = @client.enseignes.create!(name: "Enseigne test")
  end

  test "valid service saves without errors" do
    service = Service.new(enseigne: @enseigne, name: "Coupe", duration_minutes: 30, price_cents: 2500)
    assert service.valid?
  end

  test "name is required" do
    service = Service.new(enseigne: @enseigne, name: nil, duration_minutes: 30, price_cents: 2500)
    assert_not service.valid?
    assert_includes service.errors[:name], "can't be blank"
  end

  test "duration_minutes is required" do
    service = Service.new(enseigne: @enseigne, name: "Coupe", duration_minutes: nil, price_cents: 2500)
    assert_not service.valid?
    assert_includes service.errors[:duration_minutes], "can't be blank"
  end

  test "duration_minutes must be strictly positive" do
    zero_duration = Service.new(enseigne: @enseigne, name: "Coupe", duration_minutes: 0, price_cents: 2500)
    negative_duration = Service.new(enseigne: @enseigne, name: "Coupe", duration_minutes: -30, price_cents: 2500)

    assert_not zero_duration.valid?
    assert_includes zero_duration.errors[:duration_minutes], "must be greater than 0"

    assert_not negative_duration.valid?
    assert_includes negative_duration.errors[:duration_minutes], "must be greater than 0"
  end

  test "price_cents is required" do
    service = Service.new(enseigne: @enseigne, name: "Coupe", duration_minutes: 30, price_cents: nil)
    assert_not service.valid?
    assert_includes service.errors[:price_cents], "can't be blank"
  end

  test "price_cents must be positive or zero" do
    service = Service.new(enseigne: @enseigne, name: "Coupe", duration_minutes: 30, price_cents: -1)

    assert_not service.valid?
    assert_includes service.errors[:price_cents], "must be greater than or equal to 0"
  end

  test "service must belong to an enseigne" do
    service = Service.new(enseigne: nil, name: "Coupe", duration_minutes: 30, price_cents: 2500)
    assert_not service.valid?
  end

  test "service does not expose a direct client association" do
    assert_nil Service.reflect_on_association(:client)
  end

  test "database enforces non null name" do
    timestamp = Time.current

    assert_raises ActiveRecord::NotNullViolation do
      Service.insert_all!([
        { enseigne_id: @enseigne.id, name: nil, duration_minutes: 30, price_cents: 2500, created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "database enforces non null duration_minutes" do
    timestamp = Time.current

    assert_raises ActiveRecord::NotNullViolation do
      Service.insert_all!([
        { enseigne_id: @enseigne.id, name: "Coupe", duration_minutes: nil, price_cents: 2500, created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "database enforces non null price_cents" do
    timestamp = Time.current

    assert_raises ActiveRecord::NotNullViolation do
      Service.insert_all!([
        { enseigne_id: @enseigne.id, name: "Coupe", duration_minutes: 30, price_cents: nil, created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "database enforces non null enseigne_id" do
    timestamp = Time.current

    assert_raises ActiveRecord::NotNullViolation do
      Service.insert_all!([
        { enseigne_id: nil, name: "Coupe", duration_minutes: 30, price_cents: 2500, created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "database enforces positive duration_minutes" do
    timestamp = Time.current

    assert_raises ActiveRecord::StatementInvalid do
      Service.insert_all!([
        { enseigne_id: @enseigne.id, name: "Coupe", duration_minutes: 0, price_cents: 2500, created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "database enforces non negative price_cents" do
    timestamp = Time.current

    assert_raises ActiveRecord::StatementInvalid do
      Service.insert_all!([
        { enseigne_id: @enseigne.id, name: "Coupe", duration_minutes: 30, price_cents: -1, created_at: timestamp, updated_at: timestamp }
      ])
    end
  end

  test "destroying service destroys associated bookings" do
    service = @enseigne.services.create!(name: "Coupe homme", duration_minutes: 30, price_cents: 2500)
    staff = @enseigne.staffs.create!(name: "Staff service destroy", active: true)
    @client.bookings.create!(
      enseigne: @enseigne,
      service: service,
      staff: staff,
      booking_start_time: 2.days.from_now.change(hour: 11, min: 0, sec: 0),
      booking_end_time: 2.days.from_now.change(hour: 11, min: 30, sec: 0),
      booking_status: :confirmed,
      customer_first_name: "Marie",
      customer_last_name: "Martin",
      customer_email: "marie@example.com"
    )

    assert_difference "Booking.count", -1 do
      service.destroy
    end
  end
end
