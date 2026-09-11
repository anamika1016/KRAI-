require "test_helper"

class DashboardLoadingPerformanceTest < ActiveSupport::TestCase
  test "progress bill lookup loads once and preserves all legacy labels and order" do
    controller = ModulesController.new
    first = Vrp.new(id: 81001, name: "Performance JJ", user_name: "perf-jj", mobile_no: "9876500001")
    second = Vrp.new(id: 81002, name: "Other JJ", user_name: "other-jj", mobile_no: "9876500002")
    labels = [first.id.to_s, " PERFORMANCE JJ ", first.user_name, first.mobile_no,
      "Performance JJ - 9876500001", second.id.to_s, "unrelated", ""]
    labels.each_with_index do |label, index|
      ModuleRecord.create!(module_slug: "vrp-bill-add", data: { "select_vrp" => label }, created_at: index.minutes.ago)
    end
    original_rows = ModuleRecord.where(module_slug: "vrp-bill-add").order(created_at: :desc).to_a
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = args.last
      queries << payload[:sql] if payload[:sql].include?('"module_records"') && payload[:name] != "SCHEMA"
    end
    [first, second, first].each do |vrp|
      matches = controller.send(:vrp_bill_match_labels, vrp)
      expected = original_rows.select { |record| matches.include?(controller.send(:normalize_dashboard_text, record.data["select_vrp"])) }
      assert_equal expected.map(&:id), controller.send(:vrp_dashboard_bills, vrp).map(&:id)
    end
    assert_equal 1, queries.size, "Bill rows should be loaded once across all JJs"
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "SQL group totals preserve nulls, duplicate locations and visible scope" do
    rows = [
      { fco_id: "1004", ics_id: "A", village_id: "V", tracenet_no: "one" },
      { fco_id: "1004", ics_id: "A", village_id: "V", tracenet_no: "two" },
      { fco_id: "1006", ics_id: "A", village_id: "V", tracenet_no: " " },
      { fco_id: "1004", ics_id: nil, village_id: "V", tracenet_no: nil },
      { fco_id: "1004", ics_id: "", village_id: "", tracenet_no: "three" }
    ].map { |attributes| Afl.create!(attributes.merge(farmer_name: "Performance farmer")) }
    scope = Afl.where(id: rows.map(&:id))
    controller = ModulesController.new
    controller.define_singleton_method(:dashboard_total_afl_farmer_scope) { scope }
    columns = %i[fco_id fco fpo_id fpo_name ics_id ics_name]
    expected_ics = scope.where.not(ics_id: [nil, ""]).group(*columns).count.size
    expected_villages = scope.where.not(village_id: [nil, ""]).group(*columns, :village_id, :village_name).count.size
    assert_equal expected_ics, controller.send(:dashboard_total_afl_ics_count)
    assert_equal expected_villages, controller.send(:dashboard_total_afl_village_count)
    assert_equal 3, controller.send(:dashboard_total_afl_farmer_count)
    controller.define_singleton_method(:dashboard_total_afl_farmer_scope) { Afl.none }
    assert_equal 0, controller.send(:dashboard_total_afl_ics_count)
    assert_equal 0, controller.send(:dashboard_total_afl_village_count)
  end

  test "field lookup retains alias precedence and false blank zero handling" do
    controller = ModulesController.new
    record = ModuleRecord.new(module_slug: "training-form", data: {
      "main_activity" => "Primary", "training_topic" => "Alias", "farmer_count" => 0
    })
    assert_equal "Primary", controller.send(:module_record_field_value, record, "Main Activity")
    record.data["main_activity"] = " "
    assert_equal "Alias", controller.send(:module_record_field_value, record, "Main Activity")
    assert_equal 0, controller.send(:module_record_field_value, record, "Farmer Count")
    assert_equal "yes", controller.send(:first_present_data, { "a" => false, "b" => "yes" }, "a", "b")
  end

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
