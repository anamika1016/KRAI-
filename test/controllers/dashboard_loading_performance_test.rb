require "test_helper"

class DashboardLoadingPerformanceTest < ActiveSupport::TestCase
  test "farmer list does not calculate unrelated achievements" do
    controller = ModulesController.new
    controller.define_singleton_method(:vrp_dashboard_target_progress_rows) { |*_| raise "unnecessary progress calculation" }
    controller.define_singleton_method(:vrp_dashboard_farmer_status_sets) { |*_| raise "unnecessary status calculation" }
    controller.define_singleton_method(:vrp_dashboard_mapped_farmer_rows) { |*_, **_| [["farmer"]] }
    payload = controller.send(:vrp_dashboard_detail_payload, "mapped_farmers", nil, [], [], [], {})
    assert_equal [["farmer"]], payload[:rows]
  end

  test "monthly training query and record index are reused across farmer lookups" do
    record = ModuleRecord.create!(module_slug: "training-form", data: {
      "month" => "August", "selected_farmer_ids" => %w[10001 10002]
    })
    controller = ModulesController.new
    controller.define_singleton_method(:preload_training_target_mappings_for_records!) { |_| }
    calls = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      event = args.last
      calls << event[:sql] if event[:sql].include?("module_records") && !event[:cached]
    end
    first = controller.send(:dashboard_training_form_records_for_month, "August", farmer_ids: ["10001"])
    count = calls.size
    second = controller.send(:dashboard_training_form_records_for_month, "August", farmer_ids: ["10002"])
    assert_includes first.map(&:id), record.id
    assert_includes second.map(&:id), record.id
    assert_equal count, calls.size
    assert_equal 1, controller.instance_variable_get(:@dashboard_training_form_records_index_by_month).size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
