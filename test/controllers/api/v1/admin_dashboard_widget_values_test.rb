require "test_helper"

class Api::V1::AdminDashboardWidgetValuesTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(first_name: "Widget", last_name: "Admin", user_name: "widget_admin",
      email: "widget-admin@example.test", mobile_no: "9876500045", password: "secret", user_type: "admin", status: "Active")
    @headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(@admin)}" }
    @vrp = Vrp.new(name: "Widget JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876543210", email: "widget-jj@example.test", fcoc: "Sausar",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    @vrp.save!(validate: false)
    Afl.create!(farmer_name: "Widget Farmer", tracenet_no: "widget-farmer", fco_id: "1004",
      fco: "Sausar", ics_id: "widget-ics", ics_name: "Widget ICS", village_id: "widget-village", village_name: "Widget Village")
    [["July", "July Main", "July Sub"], ["August", "August Main", "August Sub"],
      ["August", "Another Main", "Another Sub"]].each do |month, main, sub|
      target = TargetMapping.new(vrp: @vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "widget-ics",
        ics_name: "Widget ICS", village_id: "widget-village", month_name: month,
        main_activity_name: main, activity_name: sub, target_quantity: 10, opg_training_target: 10)
      target.save!(validate: false)
    end
    %w[July August].each do |month|
      ["General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS"].each do |method|
        ModuleRecord.create!(module_slug: "training-form", data: { "created_by_id" => @vrp.id.to_s,
          "month" => month, "training_method" => method, "selected_farmer_ids" => [] })
      end
    end
    @filters = { month: "July", main_activity: "All", fco: "Sausar", ics: "Widget ICS" }
    @old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @old_cache
  end

  test "billing widgets and lists match active web bills independently of target filters" do
    approved = ModuleRecord.create!(module_slug: "jeevika-jankar-bill-process",
      data: { "select_vrp" => @vrp.id.to_s, "bill_month" => "June", "status" => "Final Approved" })
    pending = ModuleRecord.create!(module_slug: "jeevika-jankar-bill-process",
      data: { "select_vrp" => @vrp.id.to_s, "bill_month" => "June", "status" => "Pending" })
    [{ "deleted" => true }, { "is_deleted" => true }, { "discarded" => true }, { "record_state" => "Inactive" }].each do |flags|
      ModuleRecord.create!(module_slug: "jeevika-jankar-bill-process",
        data: { "select_vrp" => @vrp.id.to_s, "status" => "Final Approved" }.merge(flags))
    end
    filters = @filters.merge(month: "June", main_activity: "No matching targets")
    { "bill_approved" => approved, "bill_pending" => pending }.each do |widget, bill|
      assert_equal 1, widget_value(widget, filters)
      get "/api/v1/admin-dashboard/lists/#{widget}", params: filters, headers: @headers
      assert_response :success
      rows = response.parsed_body.fetch("records")
      assert_equal [bill.id], rows.map { |row| row.fetch("id") }
      assert_equal @vrp.name, rows.first.fetch("name")
      assert_equal bill.data["status"], rows.first.fetch("status")
    end
    web = ModulesController.new
    web.request = ActionDispatch::TestRequest.create
    web.params = ActionController::Parameters.new(filters)
    web.instance_variable_set(:@dashboard_month_filter_value, "June")
    web.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
    billing = web.send(:dashboard_cards).find { |card| card[:title] == "Jeevika Jankar Billing" }
    assert_equal [1, 1], billing.fetch(:items).map { |item| item.fetch(:value) }
    %w[bill_approved bill_pending].each do |widget|
      assert_equal 0, widget_value(widget, filters.merge(month: "December"))
      get "/api/v1/admin-dashboard/lists/#{widget}", params: filters.merge(month: "December"), headers: @headers
      assert_response :success
      assert_empty response.parsed_body.fetch("records")
    end
  end

  test "mapped indicator widgets respect selected month including all months" do
    { "July" => 1, "August" => 2, "All" => 3 }.each do |month, expected|
      %w[total_mapped_main_activities total_mapped_sub_activities].each do |widget|
        assert_equal expected, widget_value(widget, @filters.merge(month: month)), "#{widget}: #{month}"
      end
    end
  end

  test "target records list uses the same assignment grouping as the dashboard count" do
    expected = widget_value("target_records", @filters.merge(month: "August"))
    get "/api/v1/admin-dashboard/lists/target_records", params: @filters.merge(month: "August"), headers: @headers
    assert_response :success
    assert_equal expected, response.parsed_body.fetch("records").size
  end

  test "Direct to HO required and vacant cards match the web filtered target set" do
    @vrp.update_column(:fcoc, "FCO-Direct to HO")
    [
      ["direct-village-filtered", "Farmers' Training"],
      ["direct-village-other-activity", "Other Activity"]
    ].each do |village_id, main_activity|
      TargetMapping.new(vrp: @vrp, fco_id: "1095", fco_name: "Direct to HO", ics_id: "direct-ics",
        ics_name: "Direct ICS", village_id: village_id, village_name: village_id,
        month_name: "August", main_activity_name: main_activity, activity_name: "Soil",
        target_quantity: 1).save!(validate: false)
    end
    filters = { month: "August", main_activity: "Farmers' Training", sub_activity: "All", fco: "All", ics: "All" }

    web = ModulesController.new
    web.request = ActionDispatch::TestRequest.create
    web.response = ActionDispatch::TestResponse.new
    web.params = ActionController::Parameters.new(filters)
    api = Api::V1::UserDashboardController.new
    api.define_singleton_method(:current_api_user) { @admin }
    web.instance_variable_set(:@current_app_user, api.send(:current_api_user_payload))
    web.send(:dashboard)
    expected = web.instance_variable_get(:@dashboard_cards).find { |card| card[:title] == "FCO-wise JJ Requirement" }
      .fetch(:items).select { |item| item[:title].start_with?("Direct to HO ") }
      .to_h { |item| [item[:title], item[:value]] }

    get "/api/v1/user-dashboard", params: filters, headers: @headers

    assert_response :success
    actual = response.parsed_body.fetch("sections").find { |section| section["key"] == "fco_requirement" }
      .fetch("cards").select { |card| card["title"].start_with?("Direct to HO ") }
      .to_h { |card| [card["title"], card["value"]] }
    assert_equal expected, actual
  end

  test "mapped indicator lists return the same row count the widget shows" do
    %w[All August].each do |month|
      # A selected main activity narrows the dashboard view but not these widgets,
      # so the drill-down list has to span every indicator the widget counted.
      filters = @filters.merge(month: month, main_activity: "August Main")
      %w[total_mapped_main_activities total_mapped_sub_activities].each do |widget|
        expected = widget_value(widget, filters)
        get "/api/v1/admin-dashboard/lists/#{widget}", params: filters, headers: @headers
        assert_response :success
        assert_equal expected, response.parsed_body.fetch("records").size, "#{widget}: #{month}"
      end
    end
  end

  test "ICS villages and farmers use AFL totals even without targets in the selected month" do
    %w[total_ics_count total_villages_count total_farmer_count].each do |widget|
      assert_equal 1, widget_value(widget, @filters.merge(month: "December")), widget
    end
  end

  test "all demonstration cards match report metrics and FFS aliases return a value" do
    summary = widget_value("demonstration_method")
    assert_equal 5, response.parsed_body.fetch("cards").size
    assert response.parsed_body.fetch("cards").all? { |card| card.fetch("value").is_a?(Numeric) }
    { "opg_training_target" => "OPG Target", "general_training_meeting" => "General Training/Meeting",
      "input_demo_inm" => "Input Demo INM", "input_demo_pm" => "Input Demo PM",
      "ffs" => "FFS", "ffs_exposure" => "FFS" }.each do |widget, metric|
      expected = summary.sum { |row| row.fetch(metric).to_f }
      assert_operator expected, :>, 0
      assert_equal expected, widget_value(widget), widget
    end
  end

  test "CC JJ widget matches the shared report for month and FCO" do
    web = ModulesController.new
    web.request = ActionDispatch::TestRequest.create
    web.params = ActionController::Parameters.new(@filters)
    web.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
    assert_equal MobileDashboardReportCards.cc_jj_rows(CcJjWorkStatusReport.new(calculator: web).summary), widget_value("cc_jj_work_status")
    assert_equal %w[Sausar Turekela], response.parsed_body.fetch("groups").map { |group| group.fetch("fco_name") }
  end

  private

  def widget_value(widget, filters = @filters)
    get "/api/v1/admin-dashboard/widgets/#{widget}", params: filters, headers: @headers
    assert_response :success
    response.parsed_body.fetch("value")
  end
end
