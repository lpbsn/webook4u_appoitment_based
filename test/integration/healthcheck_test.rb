# frozen_string_literal: true

require "test_helper"

class HealthcheckTest < ActionDispatch::IntegrationTest
  test "GET /up returns success" do
    get rails_health_check_path

    assert_response :success
    assert_includes response.body, "background-color: green"
  end
end
