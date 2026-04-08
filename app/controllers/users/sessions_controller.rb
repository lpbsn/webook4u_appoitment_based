class Users::SessionsController < Devise::SessionsController
  before_action :store_redirect_to_in_session, only: %i[new create]

  def destroy
    redirect_to = params[:redirect_to].presence

    signed_out = if Devise.sign_out_all_scopes
      sign_out
    else
      sign_out(resource_name)
    end

    set_flash_message! :notice, :signed_out if signed_out

    redirect_to(
      redirect_to.present? ? new_user_session_path(redirect_to: redirect_to) : new_user_session_path,
      status: Devise.responder.redirect_status
    )
  end

  protected

  def after_sign_in_path_for(resource)
    session.delete(:after_auth_redirect_to).presence || super
  end

  private

  def store_redirect_to_in_session
    return if params[:redirect_to].blank?

    session[:after_auth_redirect_to] = params[:redirect_to]
  end
end
