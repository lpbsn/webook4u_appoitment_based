require "test_helper"

class Bookings::CreatePendingTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @client = Client.create!(
      name: "Le Salon Des gâté",
      slug: "salon-des-gate"
    )

    @enseigne = @client.enseignes.create!(
      name: "Enseigne principale"
    )

    @service = @enseigne.services.create!(
      name: "Coupe homme",
      duration_minutes: 30,
      price_cents: 2500
    )
    @staff = @enseigne.staffs.create!(name: "Staff principal", active: true)

    create_weekday_opening_hours_for_enseigne(@enseigne)
    create_weekday_staff_availabilities_for(@staff)
    StaffServiceCapability.create!(staff: @staff, service: @service)
    ServiceAssignmentCursor.find_or_create_by!(service: @service)
  end

  test "creates a pending booking for a valid slot" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot
      ).call

      assert result.success?, "CreatePending should succeed for valid slot; got error_code=#{result.error_code.inspect}"
      assert_not_nil result.booking
      assert_nil result.error_message

      booking = result.booking
      assert_equal "pending", booking.booking_status, "Booking should be pending after CreatePending success"
      assert_equal @enseigne.id, booking.enseigne_id
      assert_equal @staff.id, booking.staff_id
      assert_equal slot, booking.booking_start_time
      assert_equal slot + 30.minutes, booking.booking_end_time
      assert_not_nil booking.booking_expires_at
    end
  end

  test "creates a pending booking with the explicit enseigne provided by the public flow" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 30, 0)

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot
      ).call

      assert result.success?
      assert_equal @enseigne.id, result.booking.enseigne_id
      assert_equal @staff.id, result.booking.staff_id
    end
  end

  test "uses CreatePendingStaffRevalidation with the same booking context under lock" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 11, 30, 0)
      calls = []

      revalidation_singleton = class << Bookings::CreatePendingStaffRevalidation; self; end
      revalidation_singleton.alias_method :new_without_create_pending_orchestration_test, :new
      revalidation_singleton.define_method(:new) do |**kwargs|
        calls << kwargs.slice(:client, :enseigne, :service, :booking_start_time, :staff)
        new_without_create_pending_orchestration_test(**kwargs)
      end

      begin
        result = Bookings::CreatePending.new(
          client: @client,
          enseigne: @enseigne,
          service: @service,
          booking_start_time: slot
        ).call

        assert result.success?
        assert_equal 1, calls.size

        first_call = calls.first

        assert_equal @client, first_call[:client]
        assert_equal @enseigne, first_call[:enseigne]
        assert_equal @service, first_call[:service]
        assert_equal @staff, first_call[:staff]
        assert_equal slot, first_call[:booking_start_time]
      ensure
        revalidation_singleton.alias_method :new, :new_without_create_pending_orchestration_test
        revalidation_singleton.remove_method :new_without_create_pending_orchestration_test
      end
    end
  end

  test "does not consult AvailableSlots during transactional pending creation" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      available_slots_singleton = class << Bookings::AvailableSlots; self; end
      available_slots_singleton.alias_method :new_without_create_pending_available_slots_test, :new
      available_slots_singleton.define_method(:new) do |*_args, **_kwargs|
        raise "AvailableSlots should not be called by CreatePending"
      end

      begin
        result = Bookings::CreatePending.new(
          client: @client,
          enseigne: @enseigne,
          service: @service,
          booking_start_time: slot
        ).call

        assert result.success?
      ensure
        available_slots_singleton.alias_method :new, :new_without_create_pending_available_slots_test
        available_slots_singleton.remove_method :new_without_create_pending_available_slots_test
      end
    end
  end

  test "does not use Resource.for_enseigne during create_pending orchestration" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      resource_singleton = class << Bookings::Resource; self; end
      resource_singleton.alias_method :for_enseigne_without_create_pending_resource_test, :for_enseigne
      resource_singleton.define_method(:for_enseigne) do |*_args, **_kwargs|
        raise "Resource.for_enseigne should not be called by CreatePending"
      end

      begin
        result = Bookings::CreatePending.new(
          client: @client,
          enseigne: @enseigne,
          service: @service,
          booking_start_time: Time.zone.local(2026, 3, 16, 10, 0, 0)
        ).call

        assert result.success?
      ensure
        resource_singleton.alias_method :for_enseigne, :for_enseigne_without_create_pending_resource_test
        resource_singleton.remove_method :for_enseigne_without_create_pending_resource_test
      end
    end
  end

  test "uses cursor rotation order and wraps around on candidates" do
    second_staff = @enseigne.staffs.create!(name: "Staff secondaire", active: true)
    create_weekday_staff_availabilities_for(second_staff)
    StaffServiceCapability.create!(staff: second_staff, service: @service)

    cursor = ServiceAssignmentCursor.find_by!(service: @service)
    cursor.update!(last_confirmed_staff: second_staff)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot
      ).call

      assert result.success?
      assert_equal @staff.id, result.booking.staff_id
    end
  end

  test "tries next candidate in cursor order when first candidate is blocked" do
    second_staff = @enseigne.staffs.create!(name: "Staff secondaire", active: true)
    create_weekday_staff_availabilities_for(second_staff)
    StaffServiceCapability.create!(staff: second_staff, service: @service)

    cursor = ServiceAssignmentCursor.find_by!(service: @service)
    cursor.update!(last_confirmed_staff: @staff)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: second_staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Leonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot
      ).call

      assert result.success?
      assert_equal @staff.id, result.booking.staff_id
    end
  end

  test "acquires service lock then staff locks in rotation order during transactional candidate attempts" do
    second_staff = @enseigne.staffs.create!(name: "Staff lock order", active: true)
    create_weekday_staff_availabilities_for(second_staff)
    StaffServiceCapability.create!(staff: second_staff, service: @service)

    cursor = ServiceAssignmentCursor.find_by!(service: @service)
    cursor.update!(last_confirmed_staff: @staff)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 9, 30, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: second_staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Blocked",
        customer_last_name: "First",
        customer_email: "blocked.first@example.com"
      )

      calls = []
      slot_lock_singleton = class << Bookings::SlotLock; self; end
      slot_lock_singleton.alias_method :with_service_rotation_lock_without_create_pending_lock_order_test, :with_service_rotation_lock
      slot_lock_singleton.alias_method :with_staff_lock_without_create_pending_lock_order_test, :with_staff_lock
      slot_lock_singleton.define_method(:with_service_rotation_lock) do |service:, &block|
        calls << [ :service, service.id ]
        block.call
      end
      slot_lock_singleton.define_method(:with_staff_lock) do |staff:, &block|
        calls << [ :staff, staff.id ]
        block.call
      end

      begin
        result = Bookings::CreatePending.new(
          client: @client,
          enseigne: @enseigne,
          service: @service,
          booking_start_time: slot
        ).call

        assert result.success?
        assert_equal @staff.id, result.booking.staff_id
        assert_equal [
          [ :service, @service.id ],
          [ :staff, second_staff.id ],
          [ :staff, @staff.id ]
        ], calls
      ensure
        slot_lock_singleton.alias_method :with_service_rotation_lock, :with_service_rotation_lock_without_create_pending_lock_order_test
        slot_lock_singleton.alias_method :with_staff_lock, :with_staff_lock_without_create_pending_lock_order_test
        slot_lock_singleton.remove_method :with_service_rotation_lock_without_create_pending_lock_order_test
        slot_lock_singleton.remove_method :with_staff_lock_without_create_pending_lock_order_test
      end
    end
  end

  test "does not advance cursor on pending creation" do
    second_staff = @enseigne.staffs.create!(name: "Staff secondaire", active: true)
    create_weekday_staff_availabilities_for(second_staff)
    StaffServiceCapability.create!(staff: second_staff, service: @service)

    cursor = ServiceAssignmentCursor.find_by!(service: @service)
    cursor.update!(last_confirmed_staff: second_staff)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 30, 0)

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot
      ).call

      assert result.success?
      assert_equal @staff.id, result.booking.staff_id
      assert_equal second_staff.id, cursor.reload.last_confirmed_staff_id
    end
  end

  test "fails when booking_start_time is nil" do
    result = Bookings::CreatePending.new(
      client: @client,
      enseigne: @enseigne,
      service: @service,
      booking_start_time: nil
    ).call

    assert_not result.success?, "CreatePending should fail when slot is nil"
    assert_nil result.booking
    assert_equal Bookings::Errors::INVALID_SLOT, result.error_code
    assert_equal "Le créneau sélectionné est invalide.", result.error_message
  end

  test "fails when slot is not generated by the system" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      invalid_slot = Time.zone.local(2026, 3, 16, 8, 0, 0)

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: invalid_slot
      ).call

      assert_not result.success?
      assert_nil result.booking
      assert_equal Bookings::Errors::SLOT_NOT_BOOKABLE, result.error_code
      assert_equal "Le créneau sélectionné n'est pas réservable.", result.error_message
    end
  end

  test "fails when slot is still inside opening hours but no longer aligned with the schedule grid because of minimum notice" do
    travel_to Time.zone.local(2026, 3, 16, 14, 10, 0) do
      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 14, 30, 0)
      ).call

      assert_not result.success?
      assert_nil result.booking
      assert_equal Bookings::Errors::SLOT_NOT_BOOKABLE, result.error_code
      assert_equal "Le créneau sélectionné n'est pas réservable.", result.error_message
    end
  end

  test "fails when slot is already blocked by confirmed booking" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 11, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :confirmed,
        customer_first_name: "Leonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot
      ).call

      assert_not result.success?
      assert_nil result.booking
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
      assert_equal "Le créneau sélectionné n'est plus disponible.", result.error_message
    end
  end

  test "fails when overlapping confirmed bookings block every eligible staff candidate" do
    second_staff = @enseigne.staffs.create!(name: "Staff fully blocked", active: true)
    create_weekday_staff_availabilities_for(second_staff)
    StaffServiceCapability.create!(staff: second_staff, service: @service)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 15, 0, 0)

      [ @staff, second_staff ].each do |staff|
        @client.bookings.create!(
          enseigne: @enseigne,
          service: @service,
          staff: staff,
          booking_start_time: slot,
          booking_end_time: slot + 30.minutes,
          booking_status: :confirmed,
          customer_first_name: "Blocked",
          customer_last_name: staff.id.to_s,
          customer_email: "blocked-#{staff.id}@example.com"
        )
      end

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot
      ).call

      assert_not result.success?
      assert_nil result.booking
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
    end
  end

  test "fails when new pending overlaps confirmed booking with different start_time" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      confirmed_start = Time.zone.local(2026, 3, 16, 10, 0, 0)
      confirmed_end   = confirmed_start + 30.minutes

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: confirmed_start,
        booking_end_time: confirmed_end,
        booking_status: :confirmed,
        customer_first_name: "Leonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      overlapping_start = Time.zone.local(2026, 3, 16, 10, 15, 0)

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: overlapping_start
      ).call

      assert_not result.success?
      assert_nil result.booking
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
      assert_equal "Le créneau sélectionné n'est plus disponible.", result.error_message
    end
  end

  test "allows pending when new slot starts at confirmed booking end" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      confirmed_start = Time.zone.local(2026, 3, 16, 10, 0, 0)
      confirmed_end   = confirmed_start + 30.minutes

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: confirmed_start,
        booking_end_time: confirmed_end,
        booking_status: :confirmed,
        customer_first_name: "Leonard",
        customer_last_name: "Boisson",
        customer_email: "leo@example.com"
      )

      border_start = confirmed_end

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: border_start
      ).call

      assert result.success?
      assert_equal "pending", result.booking.booking_status
      assert_equal @staff.id, result.booking.staff_id
      assert_equal border_start, result.booking.booking_start_time
    end
  end

  test "fails when slot is already blocked by active pending booking" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 12, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :pending,
        booking_expires_at: BookingRules.pending_expires_at
      )

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot
      ).call

      assert_not result.success?
      assert_nil result.booking
      assert_equal Bookings::Errors::SLOT_UNAVAILABLE, result.error_code
      assert_equal "Le créneau sélectionné n'est plus disponible.", result.error_message
    end
  end

  test "allows slot when previous pending booking is expired" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 13, 0, 0)

      @client.bookings.create!(
        enseigne: @enseigne,
        service: @service,
        staff: @staff,
        booking_start_time: slot,
        booking_end_time: slot + 30.minutes,
        booking_status: :pending,
        booking_expires_at: 1.minute.ago
      )

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: slot
      ).call

      assert result.success?
      assert_equal "pending", result.booking.booking_status
      assert_equal @staff.id, result.booking.staff_id
      assert_equal slot, result.booking.booking_start_time
    end
  end

  test "fails without explicit enseigne" do
    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 16, 0, 0)

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: nil,
        service: @service,
        booking_start_time: slot
      ).call

      assert_not result.success?
      assert_equal Bookings::Errors::PENDING_CREATION_FAILED, result.error_code
    end
  end

  test "fails with inactive enseigne" do
    inactive_enseigne = @client.enseignes.create!(name: "Inactive", active: false)

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 16, 30, 0)

      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: inactive_enseigne,
        service: @service,
        booking_start_time: slot
      ).call

      assert_not result.success?
      assert_equal Bookings::Errors::PENDING_CREATION_FAILED, result.error_code
    end
  end

  test "fails when service belongs to another client" do
    other_client = Client.create!(
      name: "Autre salon",
      slug: "autre-salon"
    )
    other_enseigne = other_client.enseignes.create!(name: "Enseigne autre salon")
    other_service = other_enseigne.services.create!(
      name: "Massage",
      duration_minutes: 45,
      price_cents: 5000
    )

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      slot = Time.zone.local(2026, 3, 16, 10, 0, 0)

      booking_singleton = class << Booking; self; end
      booking_singleton.alias_method :create_without_service_context_guard_test!, :create!
      booking_singleton.define_method(:create!) do |_attrs|
        raise "Booking.create! should not be called for invalid service context"
      end

      begin
        result = Bookings::CreatePending.new(
          client: @client,
          enseigne: @enseigne,
          service: other_service,
          booking_start_time: slot
        ).call

        assert_not result.success?
        assert_nil result.booking
        assert_equal Bookings::Errors::PENDING_CREATION_FAILED, result.error_code
      ensure
        booking_singleton.alias_method :create!, :create_without_service_context_guard_test!
        booking_singleton.remove_method :create_without_service_context_guard_test!
      end
    end
  end

  test "uses enseigne opening hours for slot validation" do
    @enseigne.enseigne_opening_hours.delete_all
    create_weekday_opening_hours_for_enseigne(@enseigne, opens_at: "10:00", closes_at: "16:00")

    travel_to Time.zone.local(2026, 3, 15, 8, 0, 0) do
      result = Bookings::CreatePending.new(
        client: @client,
        enseigne: @enseigne,
        service: @service,
        booking_start_time: Time.zone.local(2026, 3, 16, 9, 0, 0)
      ).call

      assert_not result.success?
      assert_equal Bookings::Errors::SLOT_NOT_BOOKABLE, result.error_code
    end
  end
end
