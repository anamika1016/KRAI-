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
  test "every primary box has a list route" do
    keys = OfficeDashboardSections::SUMMARY.values + OfficeDashboardSections::DEMO +
      %w[mapped_farmer training_unique_farmers training_red training_yellow training_green]
    keys.each do |key|
      get "/api/v1/user-dashboard/lists/#{key}",
        params: { month: "June", main_activity: "Farmers' Training", sub_activity: "All", fco: "FCO-C Turekela", ics: "All" },
        headers: @headers
      assert_response :success, key
      assert_equal response.parsed_body["records"].length, response.parsed_body["count"], key
    end
  end

  test "explicit FCO and All do not fall back to a different office" do
    controller = Api::V1::UserDashboardController.new
    controller.params = ActionController::Parameters.new(fco: "FCO-C Turekela")
    assert_equal "FCO-C Turekela", controller.send(:participation_list_fcoc, Object.new, { fcos: [] })
    controller.params = ActionController::Parameters.new(fco: "All")
    assert_nil controller.send(:participation_list_fcoc, Object.new, { fcos: ["FCO-C Sausar"] })
  end

  test "participation identifiers preserve membership and historical mapping IDs" do
    farmer = Afl.create!(farmer_name: "List farmer", fco_id: "1006", fco: "Turekela",
      fpo_id: "FPO-1", fpo_name: "Test FPO", ics_id: "ICS-1", ics_name: "Test ICS",
      village_id: "V-1", village_name: "Test village")
    rows = [{ farmer_id: farmer.id.to_s, attendance_count: 2, status: "green" },
      { farmer_id: "999999999999", fco_id: "1006", ics_id: "OLD-ICS", village_id: "OLD-V", historical_mapping: true }]
    result = OfficeDashboardCalculator.new.send(:enrich_office_farmer_identifiers, rows)
    assert_equal 2, result.size
    assert_equal "1006", result.first[:fco_id]
    assert_equal "FPO-1", result.first[:fpo_id]
    assert_equal "ICS-1", result.first[:ics_id]
    assert_equal "V-1", result.first[:village_id]
    assert_equal 2, result.first[:attendance_count]
    assert_equal "green", result.first[:status]
    assert_equal "OLD-ICS", result.last[:ics_id]
    assert_nil result.last[:fpo_id]
  end

end
