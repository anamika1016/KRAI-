require "test_helper"

# The dashboard summary cards and the Target Mapping "View List" they link to are
# built by different controllers. These tests pin them together so a card can
# never advertise a number the list does not actually show.
class DashboardSummaryListParityTest < ActiveSupport::TestCase
  setup do
    @vrp = Vrp.new(name: "Parity JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876543211", email: "parity-jj@example.test", fcoc: "Sausar",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    @vrp.save!(validate: false)

    # Four sub-indicators under Farmers' Training plus one under another main
    # indicator, all in September — the shape that produced "5 outside, 4 inside".
    [
      ["Farmers' Training", "Organic Nutrient Management"],
      ["Farmers' Training", "Insect & Disease Management"],
      ["Farmers' Training", "Organic Standard"],
      ["Farmers' Training", "FFB & Internal Inspection"],
      ["Farmer Field School", "Harvest Management"]
    ].each do |main_activity, sub_activity|
      target = TargetMapping.new(vrp: @vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "parity-ics",
        ics_name: "Parity ICS", village_id: "parity-village", month_name: "September",
        main_activity_name: main_activity, activity_name: sub_activity, target_quantity: 5)
      target.save!(validate: false)
    end

    # Older rows carry the FCO name instead of its code; both sides must keep them.
    legacy = TargetMapping.new(vrp: @vrp, fco_id: "", fco_name: "Sausar", ics_id: "parity-ics",
      ics_name: "Parity ICS", village_id: "parity-village", month_name: "September",
      main_activity_name: "Farmers' Training", activity_name: "Legacy FCO Module", target_quantity: 5)
    legacy.save!(validate: false)

    # A different month must stay out of every September number.
    other = TargetMapping.new(vrp: @vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "parity-ics",
      ics_name: "Parity ICS", village_id: "parity-village", month_name: "August",
      main_activity_name: "Farmers' Training", activity_name: "August Only Module", target_quantity: 5)
    other.save!(validate: false)
  end

  test "mapped indicator cards and their view lists agree for the selected month" do
    { "sub_activity" => "Total Mapped Sub-Activities", "main_activity" => "Total Mapped Main Activities" }
      .each do |summary_mode, card_title|
      card = summary_card(card_title, month: "September", main_activity: "Farmers' Training")
      assert_equal summary_mode == "sub_activity" ? 6 : 2, card[:value], card_title

      assert_equal card[:value], list_row_count(card[:path]), "#{card_title} view list"
    end
  end

  test "view list follows the month filter dynamically" do
    card = summary_card("Total Mapped Sub-Activities", month: "August", main_activity: "Farmers' Training")
    assert_equal 1, card[:value]
    assert_equal 1, list_row_count(card[:path])
  end

  private

  def summary_card(title, filters)
    web = ModulesController.new
    web.request = admin_request(filters)
    web.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
    web.instance_variable_set(:@dashboard_month_filter_value, filters[:month])
    web.instance_variable_set(:@dashboard_main_activity_filter_value, filters[:main_activity])
    web.send(:dashboard_summary_cards, TargetMapping.all.to_a).find { |item| item[:title] == title }
  end

  # Replays the card's own "View List" link through the Target Mapping controller.
  def list_row_count(path)
    query = Rack::Utils.parse_nested_query(URI.parse(path).query)
    controller = TargetMappingsController.new
    controller.request = admin_request(query)
    controller.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
    controller.instance_variable_set(:@target_summary_mode, query["summary_mode"])
    controller.send(:target_mapping_summary_rows, controller.send(:filtered_visible_target_mappings).to_a).size
  end

  def admin_request(query)
    ActionDispatch::TestRequest.create("QUERY_STRING" => query.to_query)
  end
end
