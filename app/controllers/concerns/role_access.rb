module RoleAccess
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def require_role!(*allowed_roles)
    return if current_user && allowed_roles.include?(current_user.role.to_sym)

    redirect_to role_home_path_for(current_user), alert: "You are not allowed to access this area."
  end
end
