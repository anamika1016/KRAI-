require "test_helper"

# A dashboard opened with no month filter must land on the current month.
# The default used to be the previous month and was copy-pasted across the web
# dashboard, both mobile APIs and the CC reports, so these tests pin the shared
# default and one screen on each side of it.
class DashboardDefaultMonthTest < ActionDispatch::IntegrationTest
  # Mid-September, so "current" (September) and "previous" (August) are distinct
  # and the assertions cannot pass by accident at a month boundary.
  FROZEN_NOW = Time.zone.local(2026, 9, 15, 10).freeze

  setup do
    user = User.create!(first_name: "Default", last_name: "Month", user_name: "default_month_admin",
      email: "default-month@example.test", mobile_no: "9876500099", password: "secret",
      user_type: "admin", status: "Active")
    @headers = { "Authorization" => "Bearer #{ApiAuthToken.encode(user)}" }
    @vrp = Vrp.new(name: "Default Month JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876543299", email: "default-month-jj@example.test", fcoc: "Sausar",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    @vrp.save!(validate: false)

    # September gets two sub-indicators, August only one, so the month a
    # dashboard defaults to is visible in the count itself.
    [["September", "Sept Sub One"], ["September", "Sept Sub Two"], ["August", "Aug Sub Only"]].each do |month, sub|
      target = TargetMapping.new(vrp: @vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "default-ics",
        ics_name: "Default ICS", village_id: "default-village", month_name: month,
        main_activity_name: "Farmers' Training", activity_name: sub, target_quantity: 5)
      target.save!(validate: false)
    end

    @old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @old_cache }

  test "the shared default is the current month, not the previous one" do
    travel_to(FROZEN_NOW) do
      assert_equal "September", DashboardDefaults.month
      refute_equal Date.current.prev_month.strftime("%B"), DashboardDefaults.month
    end
  end

  test "admin dashboard widget with no month filter uses the current month" do
    travel_to(FROZEN_NOW) do
      assert_equal 2, widget_value("total_mapped_sub_activities"), "should count September, not August"
    end
  end

  test "an explicitly chosen month still overrides the default" do
    travel_to(FROZEN_NOW) do
      assert_equal 1, widget_value("total_mapped_sub_activities", month: "August")
      assert_equal 3, widget_value("total_mapped_sub_activities", month: "All")
    end
  end

  test "the drill-down list agrees with the defaulted widget" do
    travel_to(FROZEN_NOW) do
      expected = widget_value("total_mapped_sub_activities")
      get "/api/v1/admin-dashboard/lists/total_mapped_sub_activities", params: base_filters, headers: @headers
      assert_response :success
      assert_equal expected, response.parsed_body.fetch("records").size
    end
  end

  private

  def base_filters
    { main_activity: "All", fco: "Sausar", ics: "Default ICS" }
  end

  def widget_value(widget, extra = {})
    get "/api/v1/admin-dashboard/widgets/#{widget}", params: base_filters.merge(extra), headers: @headers
    assert_response :success
    response.parsed_body.fetch("value")
  end
end
