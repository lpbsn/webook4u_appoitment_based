class Users::RegistrationsController < Devise::RegistrationsController
  before_action :store_redirect_to_in_session, only: %i[new create]
  before_action :require_auth_client!, only: %i[new create]

  protected

  def build_resource(hash = {})
    super
    resource.client = current_auth_client
  end

  def after_sign_up_path_for(resource)
    session.delete(:after_auth_redirect_to).presence || super
  end

  private

  def require_auth_client!
    return if current_auth_client.present?

    redirect_to "/", alert: "Inscription impossible hors contexte client."
  end
end
