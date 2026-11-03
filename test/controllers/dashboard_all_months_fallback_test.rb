require "test_helper"

# The dashboard opens on the current month. Early in a month nothing has been
# saved for it yet, so that month is absent from the Month dropdown -- the
# select then matches nothing and displays "All Months" while the page is
# still filtered to the empty month, and every month-wise panel reads zero.
class DashboardAllMonthsFallbackTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(user_name: "all_months_admin", password: "secret", first_name: "All",
      last_name: "Months", user_type: "admin", status: "Active",
      email: "all-months@example.test", mobile_no: "9876500991")
    post login_path, params: { login: "all_months_admin", password: "secret" }

    @vrp = Vrp.create!(name: "All Months JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current, aadhar_no: "123456789088",
      account_no: "1234567890", bank_name: "Bank", branch: "Branch", ifsc_code: "TEST0123456",
      address: "Address", mobile_no: "9876543288", email: "all_months_jj@example.com",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0, vrp_type_ids: [1],
      gram_panchayat_ids: [1], village_ids: [1], user_name: "all_months_jj", password: "secret",
      fcoc: "FCO-C Sausar")

    @farmer = Afl.create!(farmer_name: "All Months Farmer", tracenet_no: "am-1", fco_id: "1004",
      fco: "Sausar", ics_id: "ics-am", ics_name: "ICS AM", village_id: "v-am", village_name: "Village AM")

    # Deliberately NOT the current month, so the current month has no data.
    TargetMapping.create!(vrp: @vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "ics-am",
      ics_name: "ICS AM", village_id: "v-am", village_name: "Village AM", month_name: other_month,
      main_activity_name: "Farmers' Training", activity_name: "Soil",
      target_quantity: 1, afl_ids: [@farmer.id])
  end

  test "a current month with no data falls through to All Months" do
    get "/dashboard"
    assert_response :success

    refute_includes month_options, current_month, "setup assumption: the empty month is not on offer"
    assert_nil assigns_month, "the page must not stay filtered to a month the dropdown cannot show"
    assert_predicate filtered_targets, :positive?, "the other month's target has to be counted"
  end

  test "the Demonstration Method panel follows the same month" do
    get "/dashboard"
    assert_response :success

    report_month = @controller.instance_variable_get(:@demonstration_method_report)&.instance_variable_get(:@month)
    assert_includes [nil, ""], report_month,
      "this panel used to keep its own current-month default and read zero"
  end

  test "an explicitly chosen month is still honoured" do
    get "/dashboard", params: { month: other_month }
    assert_response :success

    assert_equal other_month, assigns_month
    assert_predicate filtered_targets, :positive?
  end

  test "explicitly choosing All Months still means all months" do
    get "/dashboard", params: { month: "" }
    assert_response :success

    assert_nil assigns_month
    assert_predicate filtered_targets, :positive?
  end

  test "a current month that does have data is still the default" do
    TargetMapping.create!(vrp: @vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "ics-am",
      ics_name: "ICS AM", village_id: "v-am", village_name: "Village AM", month_name: current_month,
      main_activity_name: "Farmers' Training", activity_name: "Soil",
      target_quantity: 1, afl_ids: [@farmer.id])

    get "/dashboard"
    assert_response :success
    assert_equal current_month, assigns_month, "the default month stays when it has something to show"
  end

  private

  def assigns_month
    @controller.instance_variable_get(:@dashboard_month_filter_value)
  end

  def filtered_targets
    Array(@controller.instance_variable_get(:@filtered_targets)).size
  end

  def month_options
    Array(@controller.instance_variable_get(:@filter_month_options))
  end

  def current_month
    @current_month ||= Date.current.strftime("%B")
  end

  # Two months back, so it is never today's month nor next month's.
  def other_month
    @other_month ||= Date.current.prev_month.prev_month.strftime("%B")
  end
end
