require "minitest/autorun"

class MobileParticipationApiUnitTest < Minitest::Test
  def setup
    @controller = Api::V1::JeevikaJankarDashboardController.new
    @calls = []
    calls = @calls
    web = Object.new
    {
      farmer_training_mapped_farmer_count_and_popups: [10, ["Sausar: 10"]],
      farmer_training_no_training_count_and_popups: [4, [], [{ no_activity: 2 }]],
      farmer_training_yellow_farmer_count_and_popups: [3, []],
      farmer_training_green_farmer_count_and_popups: [3, []]
    }.each do |method, result|
      web.define_singleton_method(method) { |**args| calls << [method, args]; result }
    end
    web.define_singleton_method(:farmer_training_participation_rows_from_sql) do |status, **args|
      calls << [status, args]
      [{ farmer_name: "Test farmer" }]
    end
    @controller.define_singleton_method(:mobile_participation_calculator) { web }
  end

  def payload(values)
    @controller.params = ActionController::Parameters.new(values)
    @controller.send(:mobile_participation_payload, "admin")
  end

  def test_summary_uses_web_cards_without_loading_farmer_list
    result = payload(status: "summary", month: "August", fco: "1004")
    assert_equal [10, 4, 3, 3], result[:cards].map { |card| card[:value] }
    assert_equal 4, @calls.size
    assert_equal({ month_name: "August", fcoc_name: "1004" }, @calls.first.last)
    assert_empty result[:farmers]
  end

  def test_pending_sublist_and_week_are_passed_to_web_sql
    result = payload(status: "training_mapped_no_entry", training_month: "July", training_fcoc: "1006", weekly_target_week: "2")
    assert_equal 1, result[:count]
    assert_equal ["training_mapped_no_entry", { month_name: "July", fcoc_name: "1006", week_number: 2 }], @calls.last
  end

  def test_pending_alias_matches_red_web_list
    result = payload(status: "pending", month: "August", week: "9")
    assert_equal "red", result[:status]
    assert_nil result[:selected_week]
    assert_equal "red", @calls.last.first
  end
end
