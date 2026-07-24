require "test_helper"

class Api::V1::JeevikaJankarDashboardControllerTest < ActionDispatch::IntegrationTest
  test "dashboard requires authentication" do
    get "/api/v1/jeevika-jankar-dashboard", as: :json
    assert_response :unauthorized
  end
end
