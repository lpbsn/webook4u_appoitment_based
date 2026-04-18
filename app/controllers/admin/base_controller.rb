class Admin::BaseController < ApplicationController
  include RoleAccess
  layout "booking"

  before_action -> { require_role!(:admin) }
end
