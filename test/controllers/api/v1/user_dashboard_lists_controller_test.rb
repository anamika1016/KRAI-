require "test_helper"

class Api::V1::UserDashboardListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      first_name: "Mobile", last_name: "FCO", user_name: "mobile_fco_#{SecureRandom.hex(3)}",
      email: "mobile_fco_#{SecureRandom.hex(3)}@example.com", mobile_no: "9#{SecureRandom.random_number(10**9).to_s.rjust(9, "0")}",
      password: "secret", user_type: "user", status: "Active", role: "FCO"
    )
    @headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(@user)}" }
  end

  test "user dashboard list is available through a separate API route" do
    get "/api/v1/user-dashboard/lists/total_registered", headers: @headers, as: :json

    assert_response :success
    assert_equal "user", response.parsed_body["dashboard_type"]
    assert_equal "Total Registered Jeevika Jankar List", response.parsed_body["title"]
    assert response.parsed_body["records"].is_a?(Array)
  end

  test "demonstration method list and export are available to office users" do
    get "/api/v1/user-dashboard/lists/demonstration_method", params: { month: "August" }, headers: @headers
    assert_response :success
    assert_equal "Demonstration Method View List", response.parsed_body["title"]
    assert_equal [], response.parsed_body["records"]

    get "/api/v1/user-dashboard/lists/demonstration_method/export", params: { month: "August" }, headers: @headers
    assert_response :success
    assert_equal XlsxExporter::MIME_TYPE, response.media_type
  end

  test "user dashboard list export returns an xlsx file" do
    get "/api/v1/user-dashboard/lists/total_registered/export", headers: @headers

    assert_response :success
    assert_equal XlsxExporter::MIME_TYPE, response.media_type
    assert_includes response.headers["Content-Disposition"], ".xlsx"
  end
end
