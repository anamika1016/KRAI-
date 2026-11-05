require "test_helper"

# Reported: the web dashboard got a TO (sub office) filter, the app did not --
# "api me to add kro ... web ka reference leke, web me koi change nahi".
#
# The API cascade now has the same step the web has between FCO and ICS:
# options, narrowing of the JJ/target scope, and narrowing of the ICS list to
# the TO's ICS TO MAPPING rows. The web dashboard is untouched.
class Api::V1::UserDashboardToFilterTest < ActionDispatch::IntegrationTest
  MONTH = "June".freeze

  setup do
    @old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    @cc = User.create!(first_name: "Tina", last_name: "Office",
      user_name: "to_filter_cc_#{SecureRandom.hex(3)}",
      email: "to-filter-#{SecureRandom.hex(3)}@example.test",
      mobile_no: "9876500961", password: "secret", user_type: "User",
      status: "Active", role: "Cluster Incharge")
    @headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(@cc)}" }

    # Two JJs in one FCO but different sub offices, each with its own target.
    # Different sub activity each, so a TO filter visibly changes a count.
    @north = create_mapped_jj("North JJ", "123456789061", "9876543261", "TO-North", "ics-north", "Module-1")
    @south = create_mapped_jj("South JJ", "123456789062", "9876543262", "TO-South", "ics-south", "Module-2")
  end

  teardown do
    Rails.cache = @old_cache
  end

  test "filter_options lists the TOs of the JJs in view" do
    tos = dashboard.dig("filter_options", "tos")
    assert_includes tos, "TO-North"
    assert_includes tos, "TO-South"
  end

  test "selecting a TO narrows the counts to that sub office only" do
    all = dashboard
    north = dashboard(to: "TO-North")

    assert_equal "TO-North", north.dig("filters", "to"), "the applied filter is echoed back"
    assert_equal 2, sub_activities(all), "both sub offices' activities are counted with no TO"
    assert_equal 1, sub_activities(north), "only the North sub office's activity remains"
  end

  test "the TO filter accepts to_name as well as to" do
    assert_equal sub_activities(dashboard(to: "TO-South")), sub_activities(dashboard(to_name: "TO-South"))
    assert_equal 1, sub_activities(dashboard(to_name: "TO-South"))
  end

  test "a TO spelled with different spacing selects the same sub office" do
    assert_equal sub_activities(dashboard(to: "TO-North")), sub_activities(dashboard(to: "TO - North")),
      "TO labels are stored inconsistently, so the filter matches on the normalised key"
  end

  # The strongest check: the app must report what the web reports.
  test "the TO filtered counts match the web dashboard for the same request" do
    %w[TO-North TO-South].each do |to|
      assert_equal web_sub_activities(to), sub_activities(dashboard(to: to)),
        "Total Mapped Sub-Activities for #{to} must match the web"
    end
  end

  test "the ICS list is narrowed to the selected TO" do
    ics = dashboard(to: "TO-North").dig("filter_options", "ics_names")
    assert_includes ics, "ICS ics-north"
    refute_includes ics, "ICS ics-south", "the other sub office's ICS must drop out"
  end

  test "the filters endpoint offers TO between FCO and ICS" do
    get "/api/v1/user-dashboard/filters", params: { month: MONTH }, headers: @headers
    assert_response :success

    body = response.parsed_body
    keys = body.fetch("filters").map { |group| group["key"] }
    assert_includes keys, "to"
    assert_equal keys.index("fco") + 1, keys.index("to"), "TO sits straight after FCO"
    assert_operator keys.index("to"), :<, keys.index("ics"), "and before ICS"

    group = body.fetch("filters").find { |item| item["key"] == "to" }
    assert_equal "TO", group["heading"]
    assert_equal "All TO", group["all_option"]
    assert_includes group["options"], "TO-North"
    assert_includes body.fetch("filter_order"), "to"
  end

  # The web pins a login that carries its own Sub Office Name to that TO, as
  # both the selected value and the only choice.
  test "a login with its own sub office sees only that TO" do
    @cc.update_column(:sub_office_name, "TO-South") if User.column_names.include?("sub_office_name")
    skip "users table has no sub_office_name column" unless User.column_names.include?("sub_office_name")

    body = dashboard
    assert_equal ["TO-South"], body.dig("filter_options", "tos")
    assert_equal 1, sub_activities(body)
  end

  private

  def dashboard(extra = {})
    get "/api/v1/user-dashboard", params: { month: MONTH }.merge(extra), headers: @headers
    assert_response :success
    response.parsed_body
  end

  def sub_activities(body)
    Array(body.fetch("sections"))
      .flat_map { |section| Array(section["cards"]) }
      .find { |card| card["title"] == "Total Mapped Sub-Activities" }
      &.fetch("value").to_i
  end

  def web_sub_activities(to)
    controller = ModulesController.new
    query = { month: MONTH, to: to }
    controller.request = ActionDispatch::TestRequest.create("QUERY_STRING" => query.to_query)
    controller.response = ActionDispatch::TestResponse.new
    controller.params = ActionController::Parameters.new(query)
    payload = ApplicationController.new.send(:app_user_session_payload, @cc)
    controller.define_singleton_method(:current_app_user) { payload }
    controller.define_singleton_method(:render) { |*| nil }
    controller.dashboard

    Array(controller.instance_variable_get(:@dashboard_summary_cards))
      .find { |card| card[:title] == "Total Mapped Sub-Activities" }&.dig(:value).to_i
  end

  def create_mapped_jj(name, aadhar, mobile, to_name, ics_id, activity)
    vrp = Vrp.new(name: name, father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: aadhar, account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: mobile, email: "#{aadhar}@example.test",
      fcoc: "FCO-C Sausar", to_name: to_name, cluster_incharge: @cc.full_name,
      is_active: true, status: 55, experience_in_years: 1,
      office_detail_id: 0, to_office_detail_id: 0)
    vrp.save!(validate: false)
    TargetMapping.new(vrp: vrp, fco_id: "1004", fco_name: "Sausar",
      ics_id: ics_id, ics_name: "ICS #{ics_id}", village_id: "village-#{ics_id}",
      month_name: MONTH, main_activity_name: "Other", activity_name: activity,
      target_quantity: 1).save!(validate: false)
    vrp
  end
end

# Found while re-scanning: /api/v1/user-dashboard renders the *admin* payload
# for an admin token (a different code path), and that path had no TO filter at
# all -- no options, and ?to= was ignored. Same web rules apply there too.
class Api::V1::AdminDashboardToFilterTest < ActionDispatch::IntegrationTest
  MONTH = "June".freeze

  setup do
    @old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    @admin = User.create!(first_name: "Admin", last_name: "ToFilter",
      user_name: "admin_to_filter_#{SecureRandom.hex(3)}",
      email: "admin-to-filter-#{SecureRandom.hex(3)}@example.test",
      mobile_no: "9876500971", password: "secret", user_type: "admin", status: "Active")
    @headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(@admin)}" }

    create_mapped_jj("Admin North JJ", "123456789091", "9876543291", "TO-North", "ics-north", "Module-1")
    create_mapped_jj("Admin South JJ", "123456789092", "9876543292", "TO-South", "ics-south", "Module-2")
  end

  teardown do
    Rails.cache = @old_cache
  end

  test "the admin payload offers the TO options" do
    tos = dashboard.dig("filter_options", "tos")
    assert_includes tos, "TO-North"
    assert_includes tos, "TO-South"
  end

  test "the admin payload applies and echoes the TO filter" do
    all = dashboard
    north = dashboard(to: "TO-North")

    assert_equal "TO-North", north.dig("filters", "to")
    assert_equal 2, sub_activities(all)
    assert_equal 1, sub_activities(north), "only the North sub office's activity is counted"
  end

  test "the admin TO filter matches on the normalised key" do
    assert_equal sub_activities(dashboard(to: "TO-North")), sub_activities(dashboard(to: "TO - North"))
  end

  test "the admin TO counts match the web dashboard" do
    %w[TO-North TO-South].each do |to|
      assert_equal web_sub_activities(to), sub_activities(dashboard(to: to)),
        "Total Mapped Sub-Activities for #{to} must match the web"
    end
  end

  private

  def dashboard(extra = {})
    get "/api/v1/user-dashboard", params: { month: MONTH }.merge(extra), headers: @headers
    assert_response :success
    body = response.parsed_body
    assert_equal "admin", body["dashboard_type"], "an admin token must land on the admin payload"
    body
  end

  def sub_activities(body)
    Array(body.dig("dashboard_summary", "cards"))
      .find { |card| card["key"] == "total_mapped_sub_activities" }&.fetch("value").to_i
  end

  def web_sub_activities(to)
    controller = ModulesController.new
    query = { month: MONTH, to: to }
    controller.request = ActionDispatch::TestRequest.create("QUERY_STRING" => query.to_query)
    controller.response = ActionDispatch::TestResponse.new
    controller.params = ActionController::Parameters.new(query)
    payload = ApplicationController.new.send(:app_user_session_payload, @admin)
    controller.define_singleton_method(:current_app_user) { payload }
    controller.define_singleton_method(:render) { |*| nil }
    controller.dashboard

    Array(controller.instance_variable_get(:@dashboard_summary_cards))
      .find { |card| card[:title] == "Total Mapped Sub-Activities" }&.dig(:value).to_i
  end

  def create_mapped_jj(name, aadhar, mobile, to_name, ics_id, activity)
    vrp = Vrp.new(name: name, father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: aadhar, account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: mobile, email: "#{aadhar}@example.test",
      fcoc: "FCO-C Sausar", to_name: to_name, is_active: true, status: 55,
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    vrp.save!(validate: false)
    TargetMapping.new(vrp: vrp, fco_id: "1004", fco_name: "Sausar",
      ics_id: ics_id, ics_name: "ICS #{ics_id}", village_id: "village-#{ics_id}",
      month_name: MONTH, main_activity_name: "Other", activity_name: activity,
      target_quantity: 1).save!(validate: false)
    vrp
  end
end
