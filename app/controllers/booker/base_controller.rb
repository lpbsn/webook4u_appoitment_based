class Booker::BaseController < ApplicationController
  include RoleAccess
  layout "booking"

  before_action -> { require_role!(:booker) }
end
