require "test_helper"

# Reported: "FCO-wise JJ Requirement and gender count data mismatch". Root
# cause -- dashboard_jj_requirement_items (the FCO-wise JJ Requirement "Active"
# count) fell back to a hardcoded "August" when no month filter was selected,
# while every Gender Count code path already fell back to DashboardDefaults.month
# (the current month). With no month param, the two cards in the same response
# silently read different months. This covers the admin API, the office/CC/
# Agronomist/FCOC API, and the "required"/"vacant" vs "active" list drill-downs
# -- the web dashboard is untouched and out of scope.
class FcoRequirementGenderMonthConsistencyTest < ActionDispatch::IntegrationTest
  setup do
    # The admin dashboard response is cached in Rails.cache (not the DB
    # transaction), so it survives across tests in the same run and leaks one
    # test's data into the next's assertions.
    @old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    # fcoc is deliberately NOT "Sausar": dashboard_fco_active_vrp_records falls
    # back to matching vrp.fcoc directly when the month-scoped target_mapping
    # query finds nothing, which would make the active count match "Sausar"
    # for *any* queried month and hide the very bug this test exists to catch.
    # The only thing that ties this JJ to Sausar is the TargetMapping below.
    @vrp = Vrp.new(name: "Consistency JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876543210", email: "consistency-jj@example.test",
      fcoc: "Unrelated Office", is_active: true, status: 55, experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    @vrp.save!(validate: false)
    # Only mapped for the current month -- an "August" fallback anywhere in
    # this chain finds nothing and reports 0 active, while the current-month
    # aware path correctly finds this one JJ.
    TargetMapping.new(vrp: @vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "consistency-ics",
      ics_name: "Consistency ICS", village_id: "consistency-village", month_name: DashboardDefaults.month,
      main_activity_name: "Farmers' Training", activity_name: "Module-1", target_quantity: 1).save!(validate: false)
  end

  teardown do
    Rails.cache = @old_cache
  end

  test "admin FCO-wise JJ Requirement Active and Gender Male widgets agree with no month filter" do
    admin = User.create!(first_name: "Admin", last_name: "Consistency", user_name: "admin_consistency",
      email: "admin-consistency@example.test", mobile_no: "9876500910", password: "secret",
      user_type: "admin", status: "Active")
    headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(admin)}" }

    get "/api/v1/admin-dashboard/widgets/sausar_active", headers: headers
    assert_response :success
    active_value = response.parsed_body.fetch("value")

    get "/api/v1/admin-dashboard/widgets/sausar_male", headers: headers
    assert_response :success
    male_value = response.parsed_body.fetch("value")

    assert_equal 1, male_value, "Sausar Male should count the current month's JJ"
    assert_equal male_value, active_value,
      "Sausar Active (FCO-wise JJ Requirement) must count the same JJ as Sausar Male (Gender Count) " \
      "for the same request -- a stale August fallback on only one of them read 0 here"
  end

  test "admin sections.fco_wise_jeevika_jankar and mobile_widget_values describe the same month" do
    admin = User.create!(first_name: "Admin", last_name: "Sections", user_name: "admin_sections",
      email: "admin-sections@example.test", mobile_no: "9876500911", password: "secret",
      user_type: "admin", status: "Active")
    headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(admin)}" }

    get "/api/v1/admin-dashboard", headers: headers
    assert_response :success
    body = response.parsed_body
    sausar = body.fetch("sections").fetch("fco_wise_jeevika_jankar").find { |row| row["fco"] == "Sausar" }
    assert_equal 1, sausar["male"]
    assert_equal body.dig("mobile_widget_values", "Sausar Male"), sausar["male"]
  end

  test "CC/Agronomist/FCOC office API: FCO-wise JJ Requirement Active card matches the Gender Male card" do
    cc = User.create!(first_name: "Priya", last_name: "Cluster", user_name: "cc_consistency_#{SecureRandom.hex(3)}",
      email: "cc-consistency-#{SecureRandom.hex(3)}@example.test", mobile_no: "9876500912",
      password: "secret", user_type: "User", status: "Active", role: "Cluster Incharge")
    @vrp.update_column(:cluster_incharge, cc.full_name)
    headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(cc)}" }

    get "/api/v1/user-dashboard", headers: headers
    assert_response :success
    sections = response.parsed_body.fetch("sections").index_by { |section| section["key"] }
    active_value = sections.fetch("fco_requirement").fetch("cards").find { |card| card["key"] == "fco_requirement_sausar_active" }["value"]
    male_value = sections.fetch("gender").fetch("cards").find { |card| card["key"] == "gender_sausar_male" }["value"]

    assert_equal 1, male_value, "Sausar Male should count the current month's JJ"
    assert_equal male_value, active_value,
      "FCO-wise JJ Requirement's Sausar Active card and Gender Count's Sausar Male card must agree for the same request"
  end

  test "CC/Agronomist/FCOC office API: the required/vacant list for one FCO stays on the same month as its active list" do
    cc = User.create!(first_name: "Priya", last_name: "ListCluster", user_name: "cc_list_consistency_#{SecureRandom.hex(3)}",
      email: "cc-list-consistency-#{SecureRandom.hex(3)}@example.test", mobile_no: "9876500913",
      password: "secret", user_type: "User", status: "Active", role: "Cluster Incharge")
    @vrp.update_column(:cluster_incharge, cc.full_name)
    headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(cc)}" }

    # Sausar's minimum requirement (34) dominates Required regardless of the
    # active count, which would hide the bug here -- Vacant (required - active)
    # does not, since 34 active-month-aware vs. 34 August-stale differs by
    # exactly the JJ this test adds.
    get "/api/v1/user-dashboard/lists/fco_requirement_sausar_vacant", headers: headers
    assert_response :success
    vacant_value = response.parsed_body.fetch("records").find { |item| item["title"] == "Sausar Vacant" }["value"]

    get "/api/v1/user-dashboard/lists/fco_requirement_sausar_active", headers: headers
    assert_response :success
    # Unlike the required/vacant list (a single {title, value} summary row),
    # the active list returns the actual matching VRP rows.
    active_value = response.parsed_body.fetch("records").size

    assert_equal 1, active_value, "Sausar Active should count the current month's JJ"
    assert_equal 34 - active_value, vacant_value,
      "Vacant must be computed against the same active count Active itself reports"
  end
end

# Found while verifying the fix above: the admin dashboard's two
# representations of FCO-wise gender counts -- sections.fco_wise_jeevika_jankar
# (exact_admin_card_data) and mobile_widget_values["<FCO> Male"/"Female"]
# (admin_api_group_items, via OfficeDashboardCalculator) -- disagreed on real
# dev data for a reason unrelated to month: admin_api_group_items (through
# OfficeDashboardCalculator's override) requires
# dashboard_vrp_active_for_requirement? (status 55/final-approved), while
# exact_admin_card_data used a plain ModulesController and skipped that check.
#
# exact_admin_card_data was also changed to count all_vrps instead of the
# activity-filtered vrps, matching admin_api_group_items's documented intent
# ("the same approved, active JJ population"). That change is not covered by
# its own test here: dashboard_fco_active_vrp_records falls back to a direct
# Vrp.where(id:) fetch for any vrp_id a month-matching target_mapping names but
# the passed-in vrps array doesn't contain, which papers over the difference
# for any JJ that has a target_mapping at all. It would only show up for a JJ
# with no target_mapping row, i.e. the vrp.fcoc-only fallback path -- still a
# correct, low-risk alignment with the stated design intent.
class AdminFcoWiseGenderScopeConsistencyTest < ActionDispatch::IntegrationTest
  setup do
    @old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @admin = User.create!(first_name: "Admin", last_name: "Scope", user_name: "admin_scope_#{SecureRandom.hex(3)}",
      email: "admin-scope-#{SecureRandom.hex(3)}@example.test", mobile_no: "9876500920",
      password: "secret", user_type: "admin", status: "Active")
    @headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(@admin)}" }
  end

  teardown do
    Rails.cache = @old_cache
  end

  def sausar_counts
    get "/api/v1/admin-dashboard", params: { month: DashboardDefaults.month, main_activity: "All" }, headers: @headers
    assert_response :success
    body = response.parsed_body
    sausar = body.fetch("sections").fetch("fco_wise_jeevika_jankar").find { |row| row["fco"] == "Sausar" }
    mw = body.fetch("mobile_widget_values")
    [sausar["male"], mw["Sausar Male"]]
  end

  test "a not-yet-approved JJ is excluded from both places the same way" do
    vrp = Vrp.new(name: "Pending JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876543298", email: "pending-jj@example.test",
      fcoc: "Unrelated Office", is_active: true, status: 25, experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    vrp.save!(validate: false)
    TargetMapping.new(vrp: vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "pending-ics",
      ics_name: "Pending ICS", village_id: "pending-village", month_name: DashboardDefaults.month,
      main_activity_name: "Farmers' Training", activity_name: "Module-1", target_quantity: 1).save!(validate: false)

    section_male, widget_male = sausar_counts
    assert_equal 0, widget_male, "a status-25 (not final-approved) JJ must not count as Active"
    assert_equal widget_male, section_male,
      "sections.fco_wise_jeevika_jankar must exclude the same not-yet-approved JJ mobile_widget_values excludes"
  end
end
