require "test_helper"

class Api::V1::CcPerformanceControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(first_name: "CC API", last_name: "Admin",
      user_name: "cc_api_#{SecureRandom.hex(4)}", email: "cc-api-#{SecureRandom.hex(4)}@example.test",
      mobile_no: "9876500941", password: "secret", user_type: "Admin", status: "Active")
    @headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(@admin)}" }
  end

  test "requires authentication" do
    get "/api/v1/cc-performance"
    assert_response :unauthorized
  end

  test "rejects invalid month" do
    get "/api/v1/cc-performance", params: { month: "Novembr" }, headers: @headers
    assert_response :unprocessable_entity
  end

  test "all months and individual month match the web calculation" do
    ["all", "August", "November"].each do |month|
      get "/api/v1/cc-performance", params: { month: month }, headers: @headers
      assert_response :success
      actual = response.parsed_body.fetch("data")

      web = ModulesController.new
      web.request = ActionDispatch::TestRequest.create
      web.response = ActionDispatch::Response.new
      web.params = ActionController::Parameters.new(month: month == "all" ? "" : month, cc_list: "true")
      web.instance_variable_set(:@current_app_user, { "user_type" => "Admin" })
      web.define_singleton_method(:render) { |*| nil }
      web.dashboard
      report = web.instance_variable_get(:@cc_dashboard_report)
      assert_equal report.target, actual.fetch("cc_target")
      assert_equal report.achievement, actual.fetch("cc_achievement")
      assert_equal report.jj_target, actual.fetch("total_opg_jj_target")
      assert_equal report.jj_achievement, actual.fetch("total_opg_jj_achievement")
      assert_equal web.instance_variable_get(:@cc_dashboard_total_jj), actual.fetch("total_jj")
      assert_equal month, actual.fetch("month")
    end
  end
end
