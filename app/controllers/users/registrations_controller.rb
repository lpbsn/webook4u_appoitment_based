class Users::RegistrationsController < Devise::RegistrationsController
  layout "booking"
  before_action :store_redirect_to_in_session, only: %i[new create]

  protected

  def build_resource(hash = {})
    super
    resource.role = :booker
    resource.client ||= current_auth_client
  end

  def after_sign_up_path_for(resource)
    session.delete(:after_auth_redirect_to)
    role_home_path_for(resource)
  end
end
