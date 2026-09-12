# Run: bin/rails runner test/mobile_dashboard_filters_unit_test.rb
require "minitest/autorun"
require "ostruct"

class MobileDashboardFiltersUnitTest < Minitest::Test
  def setup
    @controller = Api::V1::JeevikaJankarDashboardController.new
    @calculator = ModulesController.new
    @rows = [row("August", "Farmers' Training", "Soil", "FCO A", "ICS A"),
      row("August", "Farmers' Training", "Seeds", "FCO B", "ICS B"),
      row("July", "Farmers' Training", "July Only", "FCO C", "ICS C"),
      row("August", "Other", "Other Sub", "FCO D", "ICS D")]
  end

  def row(month, main, sub, fco, ics)
    OpenStruct.new(month_name: month, main_activity_name: main, activity_name: sub,
      vrp: OpenStruct.new(fcoc: fco), ics_name: ics, ics_id: nil)
  end

  def result(params)
    @controller.params = ActionController::Parameters.new(params)
    @controller.send(:mobile_dashboard_filter_options, @rows, @calculator)
  end

  def options(payload, key)
    payload[:filters].find { |group| group[:key] == key }[:options]
  end

  def test_month_main_sub_and_fco_cascade
    payload = result(month: "August", main_activity: "Farmers' Training", sub_activity: "Soil")
    assert_equal ["Seeds", "Soil"], options(payload, "sub_activity")
    assert_equal ["FCO A"], options(payload, "fco")
    assert_equal ["ICS A"], options(payload, "ics")
    assert_equal ["July", "August"], options(payload, "month")
  end

  def test_stale_children_are_cleared
    payload = result(month: "August", main_activity: "Other", sub_activity: "Soil", fco: "FCO A", ics: "ICS A")
    assert_nil payload[:applied_filters][:sub_activity]
    assert_nil payload[:applied_filters][:fco]
    assert_nil payload[:applied_filters][:ics]
    assert_equal ["Other Sub"], options(payload, "sub_activity")
  end

  def test_all_and_empty_scope
    payload = result(month: "All", main_activity: "All")
    assert_includes options(payload, "sub_activity"), "July Only"
    assert_includes options(payload, "sub_activity"), "Other Sub"
    payload = result(month: "August", main_activity: "Unknown")
    assert_empty options(payload, "fco")
    assert_empty options(payload, "ics")
  end

  def test_user_api_inherits_same_cascade
    @controller = Api::V1::UserDashboardController.new
    payload = result(month: "August", main_activity: "Farmers' Training", fco: "FCO B")
    assert_equal ["ICS B"], options(payload, "ics")
  end
end
