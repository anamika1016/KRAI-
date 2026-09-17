require "test_helper"

class Api::V1::OfficeDashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @specialist = create_user("agricultural specialist", "FCO-C Sausar")
    @cluster = create_user("Cluster Incharge", "FCO-C Sausar")
    @manager = create_user("Manager ics", "FCO-C Sausar")
    @fco = create_user("FCO-C Sausar", "FCO-C Sausar")
    @other_specialist = create_user("agricultural specialist", "FCO-C Turekela")
    @other_fco = create_user("FCO-C Turekela", "FCO-C Turekela")
    @first = create_vrp(@specialist, @cluster.full_name, "FCO-C Sausar")
    @second = create_vrp(@other_specialist, "Different Cluster", "FCO-C Turekela")
    @first_target = create_target(@first, "1004", "Office A")
    @second_target = create_target(@second, "1006", "Office B")
    ModuleRecord.create!(module_slug: "user-hierarchy-mapping", data: {
      "level_1_user" => @manager.full_name, "level_2_user" => @cluster.full_name, "status" => "Active"
    })
  end

  test "each office role receives its own JJs and dynamic filters" do
    [[@specialist, @first], [@cluster, @first], [@manager, @first], [@fco, @first],
      [@other_specialist, @second], [@other_fco, @second]].each do |user, expected|
      get "/api/v1/user-dashboard/lists/total_registered", params: { month: "All", main_activity: "All" }, headers: headers(user)
      assert_response :success
      assert_equal [expected.id], response.parsed_body["records"].map { |row| row["id"] }, user.role
      get "/api/v1/user-dashboard/filters", params: { month: "All", main_activity: "All" }, headers: headers(user)
      assert_response :success
      fcos = response.parsed_body["filters"].find { |filter| filter["key"] == "fco" }["options"]
      assert_equal [expected.fcoc], fcos, user.role
    end
  end

  test "unknown or unauthorized selections never fall back to all visible data" do
    get "/api/v1/user-dashboard", params: { month: "August", main_activity: "All", vrp_id: @second.id }, headers: headers(@specialist)
    assert_response :success
    body = response.parsed_body
    assert_equal 0, body.dig("cards", "total_registered_vrp")
    assert_equal 0, body.dig("dashboard_summary", "values", "farmer_wise_target_mapping")
    assert_equal 0, body.dig("farmer_training_participation_status", "total_unique_farmers")
  end

  test "summary list and widget share scope and explicit all months" do
    get "/api/v1/user-dashboard", params: { month: "All", main_activity: "All" }, headers: headers(@specialist)
    assert_response :success
    body = response.parsed_body
    assert_equal 1, body.dig("cards", "total_registered_vrp")
    assert_nil body.dig("farmer_training_participation_status", "selected_month")
    assert_nil body.dig("weekly_activity_target_status", "selected_month")
    get "/api/v1/user-dashboard/widgets/total_registered", params: { month: "All", main_activity: "All" }, headers: headers(@specialist)
    assert_response :success
    assert_equal body.dig("cards", "total_registered_vrp"), response.parsed_body["value"]
  end

  test "configuration requires authentication and contains live API catalogs" do
    get "/api/v1/user-dashboard/configuration"
    assert_response :unauthorized
    get "/api/v1/user-dashboard/configuration", headers: headers(@manager)
    assert_response :success
    body = response.parsed_body
    assert_equal "Manager ics", body.dig("user", "role")
    assert body["widgets"].any? { |item| item["key"] == "targeted_farmers" }
    assert body["lists"].all? { |item| item["export_endpoint"].end_with?("/export") }
    get "/api/v1/user-dashboard/configuration", headers: headers(@first)
    assert_response :forbidden
  end

  test "training records are visible in calculator without a module route slug" do
    record = ModuleRecord.create!(module_slug: "training-form", data: {
      "vrp_id" => @first.id.to_s, "created_by_record_type" => "Vrp", "created_by_id" => @first.id.to_s,
      "main_activity_type" => "Training", "main_activity" => "Farmers' Training", "sub_activity" => "Soil",
      "month" => "August", "selected_farmer_ids" => @first_target.afl_ids.map(&:to_s),
      "target_mapping_ids" => [@first_target.id.to_s]
    })
    api = Api::V1::UserDashboardController.new
    api.define_singleton_method(:current_api_user) { @test_user }
    api.instance_variable_set(:@test_user, @specialist)
    calculator = OfficeDashboardCalculator.new
    calculator.request = ActionDispatch::TestRequest.create
    calculator.params = ActionController::Parameters.new
    calculator.instance_variable_set(:@current_app_user, api.send(:current_api_user_payload))
    calculator.apply_dashboard_scope(vrps: [@first], targets: [@first_target], bills: [])
    assert calculator.send(:module_record_visible_for_current_context?, record)
    assert_includes calculator.send(:dashboard_training_participation_records, month_name: "August"), record
  end

  private

  def headers(user)
    { "Authorization" => "Bearer #{ApiAuthToken.encode(user)}" }
  end

  def create_user(role, office)
    suffix = SecureRandom.hex(4)
    User.create!(first_name: "Office", last_name: suffix, user_name: "office_#{suffix}",
      password: "secret", user_type: "User", status: "Active", role: role, office_name: office)
  end

  def create_vrp(creator, cluster, office)
    vrp = Vrp.new(name: "JJ #{creator.id}", user_name: "jj_#{SecureRandom.hex(4)}", fcoc: office,
      cluster_incharge: cluster, created_by_id: creator.id, created_by_type: "User", status: 55, is_active: true,
      father_husband_name: "Father", gender: :male, date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456", address: "Test",
      mobile_no: "9876543210", email: "#{SecureRandom.hex(4)}@example.test", experience_in_years: 1,
      office_detail_id: 0, to_office_detail_id: 0)
    vrp.save!(validate: false)
    vrp
  end

  def create_target(vrp, fco_id, ics)
    farmer = Afl.create!(farmer_name: "Farmer #{ics}", fco_id: fco_id, fco: vrp.fcoc,
      ics_id: ics, ics_name: ics, village_id: ics, village_name: ics)
    TargetMapping.create!(vrp: vrp, fco_id: fco_id, fco_name: vrp.fcoc, ics_id: ics, ics_name: ics,
      village_id: ics, village_name: ics, month_name: "August", main_activity_name: "Farmers' Training",
      activity_name: "Soil", target_quantity: 1, afl_ids: [farmer.id], opg_training_target: 1)
  end
end
