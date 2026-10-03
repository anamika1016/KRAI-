require "test_helper"

# Dashboard cards show the configured FCO-C list, never every office found in
# the raw AFL import.
class NewFcoAppearsOnDashboardTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(first_name: "New", last_name: "Fco", user_name: "new_fco_admin",
      email: "new-fco-admin@example.test", mobile_no: "9876500811", password: "secret",
      user_type: "admin", status: "Active")
    post login_path, params: { login: user.user_name, password: "secret" }

    [["1004", "Sausar"], ["1006", "Turekela"], ["1095", "Pavijetpur"]].each_with_index do |(fco_id, name), index|
      Afl.create!(farmer_name: "#{name} farmer", tracenet_no: "new-fco-#{index}",
        fco_id: fco_id, fco: name, ics_id: "ics-#{index}", ics_name: "ICS #{index}",
        village_id: "v-#{index}", village_name: "Village #{index}")
    end
  end

  test "an unconfigured FCO added to the farmer master does not reach dashboard boxes" do
    get "/dashboard", params: { month: "September", main_activity: "Farmers' Training" }
    assert_response :success
    assert_select ".cc-jj-status-fco-name", text: "Direct to HO", count: 0, message: "not configured yet"

    Afl.create!(farmer_name: "HO farmer", tracenet_no: "new-fco-ho", fco_id: "1200",
      fco: "FCO-C Direct to HO", ics_id: "ics-ho", ics_name: "ICS HO")
    FcoDirectory.reset_cache!

    get "/dashboard", params: { month: "September", main_activity: "Farmers' Training" }
    assert_response :success
    assert_select ".cc-jj-status-fco-name", text: "Direct to HO", count: 0
    assert_select ".metric-card-group-item span", text: "Direct to HO Male", count: 0
    assert_select ".metric-card-group-item span", text: "Direct to HO Active", count: 0
  end

  test "the three existing FCOs keep their boxes" do
    get "/dashboard", params: { month: "September", main_activity: "Farmers' Training" }
    assert_response :success

    %w[Sausar Turekela Pavijetpur].each do |name|
      assert_select ".cc-jj-status-fco-name", text: name, count: 1, message: name
    end
  end

  test "an Office Setup FCO-C alias does not become a dashboard FCO" do
    ModuleRecord.create!(module_slug: "office-mapping-add", data: {
      "parent_category" => "FCO-C", "office_name" => "direact to ho",
      "sub_office_name" => "TO-Pavijetpur", "status" => "Active"
    })
    FcoDirectory.reset_cache!

    assert_equal({ ics: 0, villages: 0, farmers: 0 }, summary_counts("Direct to HO"))
  end

  test "a real FCO keeps the counts it already had" do
    assert_equal({ ics: 1, villages: 1, farmers: 1 }, summary_counts("Sausar"))
    assert_equal({ ics: 1, villages: 1, farmers: 1 }, summary_counts("Turekela"))
  end

  private

  def summary_counts(fco)
    controller = ModulesController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(fcoc: fco)
    controller.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
    { ics: controller.send(:dashboard_total_afl_ics_count),
      villages: controller.send(:dashboard_total_afl_village_count),
      farmers: controller.send(:dashboard_total_afl_farmer_count) }
  end
end
