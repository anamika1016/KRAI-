require "test_helper"

# Reported: "Gender Count count missmatch ho raha month wise ... web me jo count
# aa raha hai month wise wahi api me bhi aana chahiye". The web dashboard is the
# reference and is deliberately untouched.
#
# Two separate causes were found in OfficeDashboardCalculator, both of which
# made the API read *lower* than the web:
#
#   1. The Gender Count / FCO-wise JJ Requirement cards were built from
#      @filtered_vrps (the activity-filtered JJ set) instead of the authorised
#      scope the web card uses. An empty array is truthy in Ruby, so for any
#      month whose activity filter matched no JJ the cards silently reported
#      zero for every FCO while the web reported real numbers.
#   2. dashboard_fco_active_vrp_records re-applied is_active/is_deleted and an
#      authorised-scope check on top of the web's result. The web counts every
#      approved JJ the month's target mappings name -- including one who was
#      later deactivated, and including JJs outside the login's own scope --
#      so every non-admin login read lower in the app than on the web.
#   3. The fallback the web uses when an FCO has no mapping for the month
#      matches vrp.fcoc against the login's JJ scope. This class widens that
#      scope (extra FCO aliases + the hierarchy expansion), so a Manager login
#      read *higher* than the web. See web_dashboard_vrps.
#
# The approval rule is still re-applied: a stale mapping naming a JJ who was
# never final-approved must not count. That rule is covered by
# fco_requirement_gender_month_consistency_test.rb and must keep holding.
class Api::V1::ApiGenderCountMatchesWebTest < ActionDispatch::IntegrationTest
  MONTH = "June".freeze

  setup do
    # The admin dashboard payload is cached outside the test transaction.
    @old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    @admin = User.create!(first_name: "Admin", last_name: "GenderMatch",
      user_name: "admin_gender_match_#{SecureRandom.hex(3)}",
      email: "admin-gender-match-#{SecureRandom.hex(3)}@example.test",
      mobile_no: "9876500930", password: "secret", user_type: "admin", status: "Active")

    # Approved and active -- counted by both the web and the API all along.
    @active = create_jj("Active Sausar JJ", "123456789031", "9876543231", is_active: true, status: 55)
    # Approved but deactivated afterwards. The web still counts this JJ because
    # the month's target mapping names it; the API used to drop it.
    @inactive = create_jj("Deactivated Sausar JJ", "123456789032", "9876543232", is_active: false, status: 55)
    [@active, @inactive].each { |vrp| map_to_sausar(vrp) }
  end

  teardown do
    Rails.cache = @old_cache
  end

  test "the API Gender Count matches the web Gender Count for a selected month" do
    assert_equal web_gender_items(MONTH), api_gender_items(MONTH),
      "sections.fco_wise_jeevika_jankar must report the web dashboard's Gender Count numbers"
  end

  test "an approved JJ deactivated later is counted by both, exactly as the web counts it" do
    web = web_gender_items(MONTH)
    assert_equal 2, web.fetch("Sausar Male"),
      "the web counts both mapped approved JJs, including the deactivated one"
    assert_equal web.fetch("Sausar Male"), api_gender_items(MONTH).fetch("Sausar Male")
  end

  # Cause 1. "Farmers' Training" matches none of this month's mappings, so
  # @filtered_vrps is empty -- which used to zero the whole card.
  test "an activity filter that matches no JJ does not zero the API Gender Count" do
    api = api_gender_items(MONTH, main_activity: "Farmers' Training")
    assert_equal web_gender_items(MONTH, main_activity: "Farmers' Training"), api
    assert_operator api.fetch("Sausar Male"), :>, 0,
      "Gender Count reads the authorised JJ scope, not the activity-filtered one"
  end

  # The "All Months" option submits month="".
  test "the API Gender Count matches the web under the All Months filter" do
    assert_equal web_gender_items(""), api_gender_items("")
  end

  # A caller that names no month at all: the current month has no data here, so
  # the web shows All Months and the API has to agree rather than filter on an
  # empty month.
  test "the API Gender Count matches the web when no month is requested" do
    assert_equal web_gender_items(nil), api_gender_items(nil)
  end

  private

  def create_jj(name, aadhar, mobile, is_active:, status:)
    vrp = Vrp.new(name: name, father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: aadhar, account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: mobile, email: "#{aadhar}@example.test",
      # Not "Sausar": the fcoc fallback would match for any month and hide the bug.
      fcoc: "Unrelated Office", is_active: is_active, status: status,
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    vrp.save!(validate: false)
    vrp
  end

  def map_to_sausar(vrp)
    TargetMapping.new(vrp: vrp, fco_id: "1004", fco_name: "Sausar",
      ics_id: "gender-match-ics", ics_name: "Gender Match ICS",
      village_id: "gender-match-village", month_name: MONTH,
      main_activity_name: "Other", activity_name: "Module-1",
      target_quantity: 1).save!(validate: false)
  end

  def request_params(month, extra)
    params = extra.dup
    params[:month] = month unless month.nil?
    params
  end

  def web_gender_items(month, **extra)
    controller = ModulesController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.params = ActionController::Parameters.new(request_params(month, extra))
    payload = { "id" => @admin.id, "record_type" => "User", "user_type" => "admin",
                "username" => @admin.user_name, "name" => @admin.full_name }
    controller.define_singleton_method(:current_app_user) { payload }
    controller.define_singleton_method(:render) { |*| nil }
    controller.dashboard

    card = Array(controller.instance_variable_get(:@dashboard_cards))
      .find { |group| group.is_a?(Hash) && group[:title] == "Gender Count" }
    Array(card && card[:items]).to_h { |item| [item[:title].to_s, item[:value]] }
  end

  def api_gender_items(month, **extra)
    get "/api/v1/admin-dashboard", params: request_params(month, extra),
      headers: { "Authorization" => "Bearer #{ApiAuthToken.encode(@admin)}" }
    assert_response :success

    response.parsed_body.fetch("sections").fetch("fco_wise_jeevika_jankar")
      .each_with_object({}) do |row, items|
        items["#{row['fco']} Male"] = row["male"]
        items["#{row['fco']} Female"] = row["female"]
      end
  end
end

# Reported with screenshots: the same two cards read one set of numbers on the
# web and a different set in the app, "user wise alag alag" -- a CC login saw
# only its own JJs (Sausar Active 7) where the web shows the whole FCO (48).
# Both cards must report the web's numbers for every login, not just admin.
class Api::V1::UserDashboardCardsMatchWebTest < ActionDispatch::IntegrationTest
  MONTH = "June".freeze

  setup do
    @old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    @cc = User.create!(first_name: "Priya", last_name: "Scope",
      user_name: "cc_card_scope_#{SecureRandom.hex(3)}",
      email: "cc-card-scope-#{SecureRandom.hex(3)}@example.test",
      mobile_no: "9876500941", password: "secret", user_type: "User",
      status: "Active", role: "Cluster Incharge")

    # One JJ under this CC, one in the same FCO but under nobody. The web
    # counts both because the month's target mappings name both.
    @mine = create_mapped_jj("CC Own JJ", "123456789041", "9876543241")
    @mine.update_column(:cluster_incharge, @cc.full_name)
    @theirs = create_mapped_jj("Other CC JJ", "123456789042", "9876543242")
  end

  teardown do
    Rails.cache = @old_cache
  end

  test "a CC login's Gender Count card reports the web's numbers, not just its own JJs" do
    assert_equal 2, web_card_values.fetch("Sausar Male"),
      "the web counts both mapped JJs for this CC login"
    assert_equal web_card_values.fetch("Sausar Male"), api_card_values.fetch("Sausar Male")
  end

  test "a CC login's FCO-wise JJ Requirement Active card reports the web's number" do
    assert_equal web_card_values.fetch("Sausar Active"), api_card_values.fetch("Sausar Active")
  end

  test "every Gender Count and JJ Requirement card matches the web for a CC login" do
    assert_equal web_card_values, api_card_values
  end

  # Cause 3, as its own invariant: the JJ scope these cards fall back to must
  # be the web's, never this class's widened one.
  test "web_dashboard_vrps matches an unmodified ModulesController's scope" do
    payload = ApplicationController.new.send(:app_user_session_payload, @cc)

    calculator = OfficeDashboardCalculator.new
    calculator.request = ActionDispatch::TestRequest.create
    calculator.params = ActionController::Parameters.new(month: MONTH)
    calculator.instance_variable_set(:@current_app_user, payload)

    web = ModulesController.new
    web.request = ActionDispatch::TestRequest.create
    web.params = ActionController::Parameters.new(month: MONTH)
    web.instance_variable_set(:@current_app_user, payload)

    assert_equal web.send(:dashboard_vrps).map(&:id).sort,
      calculator.send(:web_dashboard_vrps).map(&:id).sort
  end

  private

  def create_mapped_jj(name, aadhar, mobile)
    vrp = Vrp.new(name: name, father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: aadhar, account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: mobile, email: "#{aadhar}@example.test",
      fcoc: "Unrelated Office", is_active: true, status: 55,
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    vrp.save!(validate: false)
    TargetMapping.new(vrp: vrp, fco_id: "1004", fco_name: "Sausar",
      ics_id: "scope-ics", ics_name: "Scope ICS", village_id: "scope-village",
      month_name: MONTH, main_activity_name: "Other", activity_name: "Module-1",
      target_quantity: 1).save!(validate: false)
    vrp
  end

  TITLES = ["Gender Count", "FCO-wise JJ Requirement"].freeze

  def web_card_values
    controller = ModulesController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.params = ActionController::Parameters.new(month: MONTH)
    payload = ApplicationController.new.send(:app_user_session_payload, @cc)
    controller.define_singleton_method(:current_app_user) { payload }
    controller.define_singleton_method(:render) { |*| nil }
    controller.dashboard

    Array(controller.instance_variable_get(:@dashboard_cards))
      .select { |group| group.is_a?(Hash) && TITLES.include?(group[:title]) }
      .flat_map { |group| Array(group[:items]) }
      .to_h { |item| [item[:title].to_s, item[:value]] }
  end

  def api_card_values
    get "/api/v1/user-dashboard", params: { month: MONTH },
      headers: { "Authorization" => "Bearer #{ApiAuthToken.encode(@cc)}" }
    assert_response :success

    response.parsed_body.fetch("sections")
      .select { |section| TITLES.include?(section["title"]) }
      .flat_map { |section| Array(section["cards"]) }
      .to_h { |card| [card["title"].to_s, card["value"]] }
  end
end
