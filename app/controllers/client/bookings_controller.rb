class Client::BookingsController < Client::BaseController
  def index
    @reserve_path = reservation_entry_path_for(current_user)
    @bookings = Booking.includes(:enseigne, :service, :user)
                       .where(client_id: current_user.client_id)
                       .order(booking_start_time: :desc)
                       .limit(100)
  end
end
