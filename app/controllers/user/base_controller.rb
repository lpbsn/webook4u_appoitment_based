class User::BaseController < ApplicationController
  include RoleAccess
  layout "booking"

  before_action -> { require_role!(:user) }
end
