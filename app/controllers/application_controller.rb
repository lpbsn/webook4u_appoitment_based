class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[last_name first_name])
  end

  def auth_redirect_path
    params[:redirect_to].presence || session[:after_auth_redirect_to].presence
  end

  def current_auth_client
    path = auth_redirect_path
    return if path.blank?
    return unless path.start_with?("/")
    return if path.start_with?("//")

    match = path.match(%r{\A/(?<slug>[^/]+)(?:/bookings/[^/]+(?:/success)?)?\z})
    return unless match

    Client.find_by(slug: match[:slug])
  end

  def store_redirect_to_in_session
    return if params[:redirect_to].blank?

    session[:after_auth_redirect_to] = params[:redirect_to]
  end
end
