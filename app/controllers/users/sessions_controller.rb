class Users::SessionsController < Devise::SessionsController
  layout "booking"
  before_action :store_redirect_to_in_session, only: %i[new create]
  before_action :show_missing_context_alert, only: %i[new]

  def create
    Current.set(auth_client: current_auth_client) do
      super
    end
  end

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
    if current_auth_client.blank? && resource.client_user?
      sign_out(resource)
      flash[:alert] = I18n.t("devise.failure.invalid", authentication_keys: "Email")
      return new_user_session_path
    end

    session.delete(:after_auth_redirect_to)
    role_home_path_for(resource)
  end

  private

  def show_missing_context_alert
    return if auth_redirect_path.blank?
    return if current_auth_client.present?
    return if flash[:alert].present?

    flash.now[:alert] = "You must sign in from a client context."
  end
end
