require "test_helper"

class Api::V1::JjDashboardMobileTest < ActionDispatch::IntegrationTest
  setup do
    @vrp = Vrp.new(name: "Mobile JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876543210", email: "mobile-jj@example.test",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    @vrp.save!(validate: false)
    @farmer = Afl.create!(farmer_name: "Assigned Farmer", village_name: "Mobile Village", father_name: "Farmer Father")
    @target = TargetMapping.create!(vrp: @vrp, fco_id: "1004", ics_id: "M", village_id: "MV",
      village_name: "Mobile Village", month_name: "August", main_activity_name: "Farmers' Training",
      activity_name: "Soil", target_quantity: 1, afl_ids: [@farmer.id], completion_date: Date.new(2026, 8, 30))
    @headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(@vrp)}" }
    @base = "/api/v1/jeevika-jankar-dashboard"
  end

  test "every mobile endpoint requires login" do
    %w[filters widgets/mapped_villages lists/weekly_target_plan lists/mapped_farmers/export].each do |path|
      get "#{@base}/#{path}", as: :json
      assert_response :unauthorized
    end
    post "/api/v1/translate", params: { q: "Dashboard", target: "hi" }, as: :json
    assert_response :unauthorized
  end

  test "all seven widgets agree with summary and list month scopes" do
    get @base, params: { month: "August" }, headers: @headers
    assert_response :success
    summary = response.parsed_body
    assert_equal 1, summary.dig("cards", "mapped_villages")
    assert_equal 1, summary.dig("cards", "mapped_farmers")
    summary.fetch("cards").each do |key, value|
      get "#{@base}/widgets/#{key}", params: { month: "August" }, headers: @headers
      assert_response :success
      assert_equal value, response.parsed_body["value"], key
      get "#{@base}/lists/#{key}", params: { month: "August" }, headers: @headers
      assert_response :success
      assert_equal value, response.parsed_body["total"], key
      assert_equal "August", response.parsed_body.dig("filters", "month")
    end
    get "#{@base}/lists/mapped_farmers", params: { month: "August" }, headers: @headers
    assert_equal "Assigned Farmer", response.parsed_body["records"].first["farmer_name"]
  end

  test "progress and selected week include every web table metric" do
    calculator = ModulesController.new
    expected = calculator.send(:vrp_dashboard_target_progress_rows, [@target], []).first
    get "#{@base}/lists/target_progress", params: { month: "August" }, headers: @headers
    assert_response :success
    row = response.parsed_body["records"].first
    %w[week_1 week_2 week_3 week_4 opg_training general_training input_demo_inm input_demo_pm ffs].each do |key|
      assert_equal expected[key.to_sym], row[key], key
    end
    assert_equal expected[:target], row["assigned"]
    assert_equal expected[:completed], row["achieved"]
    get "#{@base}/lists/weekly_target_plan", params: { month: "August", target_week: "week_2" }, headers: @headers
    assert_response :success
    row = response.parsed_body["records"].first
    assert_equal "week_2", row["selected_week"]
    assert_equal expected[:week_2], row["week_plan"]
    assert_equal expected[:week_2_achieved], row["week_achieved"]
    assert_equal [expected[:week_2].to_f - expected[:week_2_achieved].to_f, 0].max, row["week_pending"]
    get "#{@base}/lists/weekly_target_plan/export", params: { month: "August" }, headers: @headers
    assert_response :success
    assert_equal XlsxExporter::MIME_TYPE, response.media_type
  end

  test "empty month and all months are consistent and another JJ cannot be selected" do
    get "#{@base}/filters", headers: @headers
    assert_response :success
    assert_equal "August", response.parsed_body["selected_month"]
    assert_equal 5, response.parsed_body["weeks"].size
    get "#{@base}/widgets/assigned_target", params: { month: "December" }, headers: @headers
    assert_equal 0, response.parsed_body["value"]
    get "#{@base}/lists/target_progress", params: { month: "December" }, headers: @headers
    assert_equal [], response.parsed_body["records"]
    get @base, params: { month: "all", vrp_id: @vrp.id + 1000 }, headers: @headers
    assert_response :success
    assert_nil response.parsed_body["selected_month"]
    assert_equal @vrp.id, response.parsed_body.dig("jeevika_jankar", "id")
    assert_equal 1, response.parsed_body.dig("cards", "assigned_target")
  end

  test "translation languages and identity translation work without Google" do
    get "/api/v1/translate/languages", headers: @headers
    assert_response :success
    assert_equal %w[en hi mr or gu], response.parsed_body["languages"].map { |item| item["code"] }
    post "/api/v1/translate", params: { q: ["Dashboard", "Training Form"], source: "en", target: "en" }, headers: @headers, as: :json
    assert_response :success
    assert_equal "Dashboard", response.parsed_body["translations"].first["translated_text"]
    post "/api/v1/translate", params: { q: [], target: "hi" }, headers: @headers, as: :json
    assert_response :unprocessable_entity
  end

  test "default month matches web and a real second JJ is isolated" do
    travel_to Time.zone.local(2026, 9, 11, 10) do
      september = @target.dup
      september.month_name = "September"
      september.save!
      other = @vrp.dup
      other.email = "other-mobile-jj@example.test"
      other.save!(validate: false)
      other_target = @target.dup
      other_target.vrp = other
      other_target.village_id = "PRIVATE"
      other_target.village_name = "Other JJ private village"
      other_target.save!

      get @base, headers: @headers
      assert_equal "September", response.parsed_body["selected_month"]
      get "#{@base}/lists/target_progress", headers: @headers
      assert_equal ["September"], response.parsed_body["records"].map { |row| row["month"] }.uniq
      get "#{@base}/lists/mapped_villages", params: { month: "August", vrp_id: other.id }, headers: @headers
      assert_response :success
      assert_equal ["MV"], response.parsed_body["records"].map { |row| row["village_id"] }
    end
  end

  test "mapped villages use village IDs rather than collapsing identical names" do
    another_village = @target.dup
    another_village.village_id = "SECOND"
    another_village.save!
    get "#{@base}/widgets/mapped_villages", params: { month: "August" }, headers: @headers
    assert_equal 2, response.parsed_body["value"]
    get "#{@base}/lists/mapped_villages", params: { month: "August" }, headers: @headers
    assert_equal 2, response.parsed_body["count"]
  end

  test "missing Google configuration returns a clear server setup response" do
    previous_key = ENV.delete("GOOGLE_TRANSLATE_API_KEY")
    post "/api/v1/translate", params: { q: "Dashboard", target: "hi" }, headers: @headers, as: :json
    assert_response :service_unavailable
    assert_equal "translation_not_configured", response.parsed_body["code"]
  ensure
    ENV["GOOGLE_TRANSLATE_API_KEY"] = previous_key if previous_key
  end
end
