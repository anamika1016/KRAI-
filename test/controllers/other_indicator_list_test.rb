require "test_helper"

# "View List" behind the Main Major Work Indicator - Other box: the saved Other
# Target entries the box totals, for the same month and FCO.
class OtherIndicatorListTest < ActionDispatch::IntegrationTest
  setup do
    user = User.create!(first_name: "List", last_name: "Admin", user_name: "other_list_admin",
      email: "other-list@example.test", mobile_no: "9876500901", password: "secret",
      user_type: "admin", status: "Active")
    post login_path, params: { login: user.user_name, password: "secret" }

    # The month dropdown is driven by the Month Master.
    ["July", "August", "September"].each do |month|
      ModuleRecord.create!(module_slug: "month-master", data: { "month_name" => month })
    end

    entry("FCO-C Sausar", "September", "Internal Inspection", "Documentation", "36", "30", jj: "Pinki Parihar")
    entry("Turekela", "September", "Seed Packet Distribution", "Non GMO Seed", "100", "40", jj: "Aanjana Uikey")
    entry("FCO-C Sausar", "August", "Internal Inspection", "Documentation", "500", "500", jj: "Pinki Parihar")
  end

  test "the list shows one row per entry for the selected month" do
    get other_indicator_list_path, params: { month: "September" }
    assert_response :success

    assert_select "#other_indicator_table tbody tr", 2
    assert_select "p", text: "Total: 2"
    assert_select "#other_indicator_table tbody td", text: "Internal Inspection"
    assert_select "#other_indicator_table tbody td", text: "Seed Packet Distribution"
  end

  test "the list honours the month filter" do
    get other_indicator_list_path, params: { month: "August" }
    assert_response :success

    assert_select "#other_indicator_table tbody tr", 1
    assert_select "#other_indicator_table tbody td", text: "500"
  end

  test "the list honours the FCO filter" do
    get other_indicator_list_path, params: { month: "September", fcoc: "FCO-C Sausar" }
    assert_response :success

    assert_select "#other_indicator_table tbody tr", 1
    assert_select "#other_indicator_table tbody td", text: "Internal Inspection"
  end

  test "the list is available as JSON" do
    get other_indicator_list_path(format: :json), params: { month: "September" }
    assert_response :success

    body = response.parsed_body
    assert_equal 2, body.fetch("count")
    assert_equal %w[jeevika_jankar_name fco_name month main_activity sub_activity target achievement status target_mapping_id].sort,
                 body.fetch("records").first.keys.sort
  end

  test "the list is Jeevika Jankar wise and offers month and search controls" do
    get other_indicator_list_path, params: { month: "September" }
    assert_response :success

    assert_select "#other_indicator_table thead th", text: "Jeevika Jankar"
    assert_select "#other_indicator_table tbody td", text: "Pinki Parihar"
    assert_select "#other_indicator_table tbody td", text: "Aanjana Uikey"
    assert_select "h1", text: /September/
    assert_select "select#other_indicator_month option[value=?]", "August"
    assert_select "select#other_indicator_month option[value=?]", "July"
    assert_select "input[data-table-search=?]", "other_indicator_table"
  end

  test "the month dropdown comes from the Month Master" do
    ModuleRecord.where(module_slug: "month-master").destroy_all
    ModuleRecord.create!(module_slug: "month-master", data: { "month_name" => "November" })

    get other_indicator_list_path, params: { month: "September" }
    assert_response :success

    assert_select "select#other_indicator_month option[value=?]", "November"
    assert_select "select#other_indicator_month option[value=?]", "July", count: 0
    # A month that already has entries stays selectable even if the master drops it.
    assert_select "select#other_indicator_month option[value=?]", "September"
  end

  test "the dashboard links to the list" do
    get "/dashboard", params: { month: "September" }
    assert_response :success

    assert_select "a[href*='/dashboard/other-indicator']", minimum: 1
  end

  private

  def entry(fco, month, main, sub, target, achievement, jj: "A JJ")
    ModuleRecord.create!(module_slug: "other-target", data: {
      "jeevika_jankar_name" => jj, "fcoc_name" => fco, "month" => month,
      "main_activity" => main, "sub_activity" => sub,
      "target" => target, "achievement" => achievement
    })
  end
end
