class Booker::BookingsController < Booker::BaseController
  def index
    @reserve_path = reservation_entry_path_for(current_user)
    @bookings = Booking.includes(:client, :enseigne, :service)
                       .confirmed
                       .where(user_id: current_user.id)
                       .order(booking_start_time: :desc)
                       .limit(100)
  end
end
