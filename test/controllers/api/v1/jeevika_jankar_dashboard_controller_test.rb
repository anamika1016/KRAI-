require "test_helper"

class Api::V1::JeevikaJankarDashboardControllerTest < ActionDispatch::IntegrationTest
  test "admin ICS list includes AFL offices without targets and ignores activity month" do
    user = User.create!(first_name: "ICS", last_name: "Admin", user_name: "ics_admin",
      password: "secret", user_type: "admin", status: "Active")
    headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(user)}" }
    { "1004" => ["Sausar", 11], "1006" => ["Turekela", 8], "1095" => ["Pavijetpur", 4] }.each do |id, (name, count)|
      count.times do |index|
        Afl.create!(farmer_name: "ICS farmer", fco_id: id, fco: name, fpo_id: "FPO-#{id}",
          fpo_name: "FPO #{name}", ics_id: "#{id}-#{index}", ics_name: "ICS #{id} #{index}", tracenet_no: "T-#{id}-#{index}")
      end
    end
    query = { month: "August", main_activity: "Farmers' Training", ics: "All", fco: "All" }
    get "/api/v1/admin-dashboard/lists/total_ics_count", params: query, headers: headers
    assert_response :success
    body = response.parsed_body
    assert_equal "admin", body["dashboard_type"]
    assert_equal 23, body["count"]
    assert_equal 4, body["records"].count { |row| row["fco_id"] == "1095" }
    assert body["records"].all? { |row| row["fpo_id"].present? && row["farmer_count"] == 1 }
    get "/api/v1/admin-dashboard/lists/total_ics_count", params: query.merge(fco: "1095"), headers: headers
    assert_response :success
    assert_equal 4, response.parsed_body["count"]
    get "/api/v1/admin-dashboard/lists/total_ics_count/export", params: query, headers: headers
    assert_response :success
    assert_equal XlsxExporter::MIME_TYPE, response.media_type
  end

  test "dashboard requires authentication" do
    get "/api/v1/jeevika-jankar-dashboard", as: :json
    assert_response :unauthorized
  end

  test "admin dashboard route is available to authenticated admin" do
    user = User.create!(
      first_name: "Dashboard",
      last_name: "Admin",
      user_name: "dashboard_admin",
      email: "dashboard_admin@example.com",
      mobile_no: "9876500001",
      password: "secret",
      user_type: "admin",
      status: "Active"
    )
    token = ApiAuthToken.encode(user)

    get "/api/v1/jeevika-jankar-dashboard", headers: { "Authorization" => "Bearer #{token}" }, as: :json

    assert_response :success
    assert_equal "admin", response.parsed_body["dashboard_type"]
    assert response.parsed_body.key?("farmer_training_participation_status")
    assert response.parsed_body.key?("target_dashboard")
    assert response.parsed_body["demonstration_method"].is_a?(Array)
    assert response.parsed_body.key?("weekly_activity_target_status")

    get "/api/v1/admin-dashboard/lists/demonstration_method", params: { month: "August" }, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    assert_equal "Demonstration Method View List", response.parsed_body["title"]
    get "/api/v1/admin-dashboard/lists/demonstration_method/export", params: { month: "August" }, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    assert_equal XlsxExporter::MIME_TYPE, response.media_type

    post login_path, params: { login: user.user_name, password: "secret" }
    get dashboard_path(month: "August", main_activity: "Farmer Activity")
    assert_response :success
    assert_select ".demonstration-method-report", count: 0
    assert_select "#demonstration_method_boxes h2", "Demonstration Method"
    assert_select "#demonstration_method_boxes .demonstration-common-list", text: "View List"
    assert_select "#demonstration_method_boxes .dashboard-summary-box", count: 5
    assert_select "#demonstration_method_boxes .dashboard-summary-box span", text: "FFS Exposure"
    assert_select "#demonstration_method_boxes .dashboard-summary-box span", text: "OPG Training Achievement", count: 0
    assert_select ".cc-jj-work-status", text: /CC and JJ Work Status/
    assert_operator response.body.index("Gender Count"), :<, response.body.index("CC and JJ Work Status")
    get cc_jj_work_status_list_path
    assert_response :success
    assert_select "h1", "CC and JJ Work Status View List"
    assert_select "a", text: "Export Excel"
    get cc_jj_work_status_list_path(format: :xlsx)
    assert_response :success
    assert_equal XlsxExporter::MIME_TYPE, response.media_type
    get "/api/v1/admin-dashboard/lists/cc_jj_work_status", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    assert_equal "CC and JJ Work Status View List", response.parsed_body["title"]
    get demonstration_method_list_path(month: "August")
    assert_response :success
    assert_select "h1", "Demonstration Method View List"
    assert_select "a", text: "Export Excel"
    get demonstration_method_list_path(month: "August", format: :xlsx)
    assert_response :success
    assert_equal XlsxExporter::MIME_TYPE, response.media_type
  end
end
