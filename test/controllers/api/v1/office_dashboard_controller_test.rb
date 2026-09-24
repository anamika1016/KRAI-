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

  test "complete sections expose working lists and numeric demonstration pairs" do
    get "/api/v1/user-dashboard", params: { month: "August", main_activity: "All" }, headers: headers(@specialist)
    assert_response :success
    body = response.parsed_body
    assert body["success"], body.inspect
    assert_operator body.dig("meta", "server_processing_ms"), :>=, 0
    assert response.headers["Server-Timing"].include?("dashboard;dur=")
    sections = body.fetch("sections").index_by { |section| section["key"] }
    assert_equal %w[summary participation demonstration other billing gender fco_requirement cc_jj_work_status].sort, sections.keys.sort
    demo = sections.fetch("demonstration")["cards"]
    assert_equal 6, demo.size
    assert_equal({ "target" => 0.0, "achievement" => 0.0 }, demo.find { |card| card["key"] == "input_demo_inm" }["value"])
    sections.values.flat_map { |section| section["cards"] }.each do |card|
      get card.fetch("list_endpoint"), params: { month: "August", main_activity: "All" }, headers: headers(@specialist)
      assert_response :success, card.inspect
      assert response.parsed_body["success"], card.inspect
    end
    assert sections.fetch("gender")["cards"].none? { |card| card["title"].include?("Turekela") }
  end

  test "FCO and gender cards never reload someone else's JJ in the same office" do
    hidden = create_vrp(@other_specialist, "Hidden cluster", @first.fcoc)
    create_target(hidden, "1004", "Hidden ICS")
    [@specialist, @cluster].each do |user|
      get "/api/v1/user-dashboard", params: { month: "August", main_activity: "All" }, headers: headers(user)
      assert_response :success
      cards = response.parsed_body.fetch("sections").flat_map { |section| section["cards"] }
      assert_equal 1, cards.find { |card| card["key"] == "fco_requirement_sausar_active" }["value"]
      assert_equal 1, cards.find { |card| card["key"] == "gender_sausar_male" }["value"]
      get "/api/v1/user-dashboard/lists/gender_sausar_male", params: { month: "August", main_activity: "All" }, headers: headers(user)
      assert_equal [@first.id], response.parsed_body["records"].map { |row| row["id"] }
    end
  end

  test "Other achievements do not include another JJ's entry for the same farmer" do
    @first_target.update!(main_activity_name: "Compost")
    ModuleRecord.create!(module_slug: "training-form", data: {
      "vrp_id" => @second.id.to_s, "month" => "August", "main_activity" => "Compost",
      "selected_farmer_ids" => @first_target.afl_ids.map(&:to_s)
    })
    get "/api/v1/user-dashboard/lists/other_activities", params: { month: "August", main_activity: "All" }, headers: headers(@specialist)
    assert_response :success
    rows = response.parsed_body.fetch("records")
    assert_equal 1, rows.size
    assert_equal 1, rows.first["mapped_farmer"]
    assert_equal 0, rows.first["achievement_farmer"]
    get "/api/v1/user-dashboard", params: { month: "August", main_activity: "All", vrp_id: @second.id }, headers: headers(@specialist)
    assert_response :success
    sections = response.parsed_body.fetch("sections").index_by { |section| section["key"] }
    assert sections.fetch("summary")["cards"].all? { |card| card["value"] == 0 }
    assert sections.fetch("other")["cards"].all? { |card| card["value"] == 0 }
  end

  test "CC Agronomist and FCOC role spellings use server authorization" do
    [[@cluster, "CC"], [@specialist, "Agronomist"], [@fco, "FCOC"]].each do |user, role|
      user.update!(role: role)
      get "/api/v1/user-dashboard/lists/total_registered", params: { month: "All", main_activity: "All" }, headers: headers(user)
      assert_response :success
      assert_equal [@first.id], response.parsed_body["records"].map { |row| row["id"] }, role
    end
  end

  test "cache is separated by user and filter and reports per-request timing" do
    old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    filters = { month: "August", main_activity: "All" }
    get "/api/v1/user-dashboard", params: filters, headers: headers(@specialist)
    assert_response :success
    assert_equal false, response.parsed_body.dig("meta", "cache_hit")
    first = response.parsed_body
    get "/api/v1/user-dashboard", params: filters, headers: headers(@specialist)
    assert_equal true, response.parsed_body.dig("meta", "cache_hit")
    assert_equal first["sections"], response.parsed_body["sections"]
    get "/api/v1/user-dashboard", params: filters, headers: headers(@other_specialist)
    assert_equal false, response.parsed_body.dig("meta", "cache_hit")
    assert_equal @other_specialist.id, response.parsed_body.dig("user", "id")
    get "/api/v1/user-dashboard", params: filters.merge(vrp_id: @second.id), headers: headers(@specialist)
    assert_equal false, response.parsed_body.dig("meta", "cache_hit")
    assert_equal 0, response.parsed_body.dig("cards", "total_registered_vrp")
  ensure
    Rails.cache = old_cache
  end

  test "summary counts lists exports and widgets agree for AFL groups" do
    farmer = Afl.find(@first_target.afl_ids.first)
    farmer.update!(tracenet_no: "office-unique-farmer")
    %w[summary_ics summary_villages summary_farmers].each do |key|
      get "/api/v1/user-dashboard/widgets/#{key}", params: { month: "August", main_activity: "All" }, headers: headers(@specialist)
      assert_response :success
      assert_equal 1, response.parsed_body["value"]
      get "/api/v1/user-dashboard/lists/#{key}", params: { month: "August", main_activity: "All" }, headers: headers(@specialist)
      assert_response :success
      assert_equal 1, response.parsed_body["count"]
      get "/api/v1/user-dashboard/lists/#{key}/export", params: { month: "August", main_activity: "All" }, headers: headers(@specialist)
      assert_response :success
      assert_equal XlsxExporter::MIME_TYPE, response.media_type
    end
  end

  test "each requested role applies month activity FCO ICS and JJ filters to the complete dashboard" do
    [@specialist, @cluster, @fco].each do |user|
      base = { month: "August", main_activity: "Farmers' Training", sub_activity: "Soil", fco: @first.fcoc, ics: "Office A" }
      get "/api/v1/user-dashboard", params: base, headers: headers(user)
      assert_response :success
      assert_equal 1, response.parsed_body.dig("cards", "total_registered_vrp"), user.role
      [{ month: "January" }, { main_activity: "Unknown" }, { sub_activity: "Unknown" },
        { fco: @second.fcoc }, { ics: "Office B" }, { vrp_id: @second.id }].each do |change|
        get "/api/v1/user-dashboard", params: base.merge(change), headers: headers(user)
        assert_response :success
        body = response.parsed_body
        assert_equal 0, body.dig("cards", "total_registered_vrp"), "#{user.role}: #{change}"
        assert_equal 0, body.dig("dashboard_summary", "values", "farmer_wise_target_mapping")
        assert body.fetch("sections").find { |section| section["key"] == "summary" }["cards"].all? { |card| card["value"] == 0 }
      end
    end
  end

  test "dashboard dropdowns are restricted by month and agree with filter endpoint" do
    extra = @first_target.dup
    extra.month_name = "July"
    extra.activity_name = "July-only module"
    extra.save!
    [@specialist, @cluster, @fco].each do |user|
      query = { month: "August", main_activity: "Farmers' Training" }
      get "/api/v1/user-dashboard/filters", params: query, headers: headers(user)
      assert_response :success
      subs = response.parsed_body["filters"].find { |filter| filter["key"] == "sub_activity" }["options"]
      get "/api/v1/user-dashboard", params: query, headers: headers(user)
      assert_response :success
      body = response.parsed_body
      assert_equal ["Soil"], body.dig("filter_options", "sub_activities")
      assert_equal subs, body.dig("filter_options", "sub_activities")
      section = body["sections"].find { |item| item["key"] == "summary" }
      assert_equal section["cards"].to_h { |card| [card["key"], card["value"]] }, body.dig("dashboard_summary", "counts")
    end
  end

  test "cached summary immediately reflects committed target edits" do
    old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    query = { month: "August", main_activity: "Farmers' Training" }
    get "/api/v1/user-dashboard", params: query, headers: headers(@specialist)
    assert_response :success
    assert_equal ["Soil"], response.parsed_body.dig("filter_options", "sub_activities")
    @first_target.update!(activity_name: "Updated module")
    get "/api/v1/user-dashboard", params: query, headers: headers(@specialist)
    assert_response :success
    assert_equal false, response.parsed_body.dig("meta", "cache_hit")
    assert_equal ["Updated module"], response.parsed_body.dig("filter_options", "sub_activities")
  ensure
    Rails.cache = old_cache
  end

  test "boxes endpoint matches full primary sections for each role and filters" do
    [@specialist, @cluster, @fco].each do |user|
      [{ month: "August", main_activity: "All" }, { month: "January", main_activity: "All" }].each do |query|
        get "/api/v1/user-dashboard", params: query, headers: headers(user)
        assert_response :success
        expected = response.parsed_body.fetch("sections").select { |section| %w[summary participation demonstration].include?(section["key"]) }
        get "/api/v1/user-dashboard/boxes", params: query, headers: headers(user)
        assert_response :success
        assert_equal expected, response.parsed_body.fetch("sections")
      end
    end
    get "/api/v1/user-dashboard/boxes"
    assert_response :unauthorized
    get "/api/v1/user-dashboard/boxes", headers: headers(@first)
    assert_response :forbidden
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
