require "test_helper"

class DashboardLoadingPerformanceTest < ActiveSupport::TestCase
  test "bill totals match full details without loading farmer display data" do
    vrp = Vrp.new(name: "Performance JJ", email: "performance-jj@example.test",
      aadhar_no: "123456789012", account_no: "1234", address: "Test", branch: "Test",
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      experience_in_years: 1, father_husband_name: "Test", gender: :male,
      ifsc_code: "SBIN0001234", mobile_no: "9876543210", office_detail_id: 1, to_office_detail_id: 1)
    vrp.save!(validate: false)
    farmer = Afl.create!(fco_id: "1004", farmer_name: "Performance Farmer")
    TargetMapping.create!(vrp: vrp, fco_id: "1004", ics_id: "perf", village_id: "perf",
      month_name: "August", main_activity_name: "Farmers' Training", activity_name: "Performance Training",
      target_quantity: 1, afl_ids: [farmer.id])
    TargetMapping.create!(vrp: vrp, fco_id: "1004", ics_id: "perf", village_id: "perf-other",
      month_name: "August", main_activity_name: "Other", activity_name: "Performance Other",
      target_quantity: 12, afl_ids: [])
    ModuleRecord.create!(module_slug: "training-form", data: {
      "month" => "August", "main_activity" => "Farmers' Training",
      "selected_farmer_ids" => [farmer.id.to_s], "vrp_id" => vrp.id.to_s
    })
    build_controller = lambda do
      controller = ModulesController.new
      controller.params = ActionController::Parameters.new
      controller.define_singleton_method(:vrp_login_user?) { false }
      controller.define_singleton_method(:module_mapped_vrp_scope_active?) { false }
      controller
    end
    full = build_controller.call
    full.send(:jeevika_jankar_bill_rows, vrp_id: vrp.id.to_s, month_name: "August")
    expected = full.instance_variable_get(:@jeevika_jankar_target_summary)
    assert expected.dig(vrp.id.to_s, "august")

    fast = build_controller.call
    fast.define_singleton_method(:jeevika_jankar_farmers_by_id) { |_| raise "unnecessary farmer hydration" }
    fast.define_singleton_method(:jeevika_jankar_training_index) { |_| raise "unnecessary evidence index" }
    fast.send(:jeevika_jankar_bill_rows, vrp_id: vrp.id.to_s, month_name: "August", totals_only: true)
    assert_equal expected, fast.instance_variable_get(:@jeevika_jankar_target_summary)
  end

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
