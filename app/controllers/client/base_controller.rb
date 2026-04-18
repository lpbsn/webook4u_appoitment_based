class Client::BaseController < ApplicationController
  include RoleAccess
  layout "booking"

  before_action -> { require_role!(:client_user) }
end
