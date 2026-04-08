class Users::RegistrationsController < Devise::RegistrationsController
  before_action :store_redirect_to_in_session, only: %i[new create]

  protected

  def after_sign_up_path_for(resource)
    session.delete(:after_auth_redirect_to).presence || super
  end

  private

  def store_redirect_to_in_session
    return if params[:redirect_to].blank?

    session[:after_auth_redirect_to] = params[:redirect_to]
  end
end
