require "test_helper"

class StaffTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client staff", slug: "client-staff")
    @enseigne = @client.enseignes.create!(name: "Enseigne staff")
  end

  test "valid staff saves without errors" do
    staff = Staff.new(enseigne: @enseigne, name: "Staff A")

    assert staff.valid?
  end

  test "name is required" do
    staff = Staff.new(enseigne: @enseigne, name: nil)

    assert_not staff.valid?
    assert_includes staff.errors[:name], "can't be blank"
  end

  test "enseigne is required" do
    staff = Staff.new(name: "Staff A")

    assert_not staff.valid?
  end

  test "destroying staff destroys availabilities and unavailabilities" do
    staff = @enseigne.staffs.create!(name: "Staff A")
    staff.staff_availabilities.create!(day_of_week: 1, opens_at: "09:00", closes_at: "18:00")
    staff.staff_unavailabilities.create!(starts_at: Time.current, ends_at: 1.hour.from_now)

    assert_difference "StaffAvailability.count", -1 do
      assert_difference "StaffUnavailability.count", -1 do
        staff.destroy
      end
    end
  end

  test "destroying staff nullifies associated bookings staff_id" do
    staff = @enseigne.staffs.create!(name: "Staff booked")
    service = @enseigne.services.create!(name: "Service booked", duration_minutes: 30, price_cents: 2500)
    booking = @client.bookings.create!(
      enseigne: @enseigne,
      service: service,
      staff: staff,
      booking_start_time: 2.days.from_now.change(hour: 10, min: 0, sec: 0),
      booking_end_time: 2.days.from_now.change(hour: 10, min: 30, sec: 0),
      booking_status: :pending,
      booking_expires_at: 2.days.from_now.change(hour: 10, min: 10, sec: 0)
    )

    staff.destroy
    booking.reload

    assert_nil booking.staff_id
  end
end
