# Database-free checks: run with `bin/rails runner test/dashboard_logic_unit_test.rb`.
require "minitest/autorun"
require "ostruct"

class DashboardLogicUnitTest < Minitest::Test
  def test_other_target_lookup_keeps_aliases_order_and_scope_changes
    c = controller
    first = OpenStruct.new(id: 1, vrp_id: 7, month_name: " August ", vrp: OpenStruct.new(name: "JJ Name", user_name: "jj-login"))
    second = OpenStruct.new(id: 2, vrp_id: 7, month_name: "August", vrp: first.vrp)
    july = OpenStruct.new(id: 3, vrp_id: 7, month_name: "July", vrp: first.vrp)
    c.instance_variable_set(:@other_target_candidate_targets, [first, second, july])
    %w[7 jj-login].push("jj name").each do |identity|
      assert_equal [first, second], c.send(:other_target_candidates_for_match, identity, "august")
    end
    assert_equal [july], c.send(:other_target_candidates_for_match, "7", "july")
    c.instance_variable_set(:@other_target_candidate_targets, [second])
    assert_equal [second], c.send(:other_target_candidates_for_match, "7", "august")
  end

  def test_blank_assignment_group_does_not_load_global_dashboard_targets
    c = controller
    c.define_singleton_method(:dashboard_target_mappings) { raise "unnecessary global target load" }
    c.define_singleton_method(:dashboard_target_assignment_signature) { |_| ["signature"] }
    target = OpenStruct.new(mapping_group_key: "", main_activity_name: "Training", activity_name: "Soil")
    assert_equal ["signature", "training", "soil"], c.send(:dashboard_target_assignment_key, target)
  end

  def test_widget_cache_reuses_summary_but_keeps_filters_and_users_isolated
    build = lambda do |query, user_id = "1", version = "v1"|
      c = Api::V1::JeevikaJankarDashboardController.new
      request = ActionDispatch::TestRequest.create
      request.set_header("QUERY_STRING", query)
      c.request = request
      c.define_singleton_method(:current_api_user_payload) { { "id" => user_id, "user_type" => "admin" } }
      c.define_singleton_method(:cache_table_version) { |_| version }
      c.define_singleton_method(:cache_module_records_version) { |_| version }
      c
    end
    first = build.call("month=July&widget=mapped_farmer")
    second = build.call("widget=total_mapped_sub_activities&month=July")
    key = first.send(:admin_dashboard_cache_key, "summary")
    assert_equal key, second.send(:admin_dashboard_cache_key, "summary")
    refute_equal key, build.call("month=August").send(:admin_dashboard_cache_key, "summary")
    refute_equal key, build.call("month=July", "2").send(:admin_dashboard_cache_key, "summary")
    refute_equal key, build.call("month=July", "1", "v2").send(:admin_dashboard_cache_key, "summary")
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    calls = 0
    [first, second].each do |c|
      assert_equal({ count: 42 }, c.send(:cache_admin_dashboard_payload, "summary") { calls += 1; { count: 42 } })
    end
    assert_equal 1, calls
  ensure
    Rails.cache = original_cache if original_cache
  end

  def controller(params = {})
    instance = ModulesController.new
    instance.params = ActionController::Parameters.new(params)
    instance
  end

  def test_sub_activities_follow_month_and_ics
    c = controller(month: "July", ics: "ICS A")
    targets = [
      OpenStruct.new(month_name: "July", activity_name: "July Training", ics_name: "ICS A"),
      OpenStruct.new(month_name: "August", activity_name: "August Training", ics_name: "ICS A"),
      OpenStruct.new(month_name: "July", activity_name: "Other ICS Training", ics_name: "ICS B")
    ]
    assert_equal ["July Training"], c.send(:dashboard_filter_sub_activity_options, targets)
    c = controller(month: "August", ics: "ICS A")
    assert_equal ["August Training"], c.send(:dashboard_filter_sub_activity_options, targets)
    c = controller(month: "", ics: "ICS A")
    assert_equal ["August Training", "July Training"], c.send(:dashboard_filter_sub_activity_options, targets)
  end

  def test_other_activity_totals_use_quantity_and_cap_completion
    c = controller
    c.define_singleton_method(:preload_training_farmers_for_targets!) { |_| }
    c.define_singleton_method(:vrp_dashboard_target_progress_rows) do |*_|
      [{ target: 40, completed: 30 }, { target: 20, completed: 20 }]
    end
    targets = [OpenStruct.new(id: 1, fco_id: "1004", target_quantity: 40), OpenStruct.new(id: 2, fco_id: "1006", target_quantity: 20)]
    assert_equal({ target: 60, completed: 50, pending: 10 }, c.send(:dashboard_other_activity_totals, targets))
    assert_equal({ target: 0, completed: 0, pending: 0 }, c.send(:dashboard_other_activity_totals, []))
  end

  def test_completed_payments_do_not_use_approver_visibility
    c = controller
    c.define_singleton_method(:admin_dashboard_user?) { false }
    c.define_singleton_method(:cached_vrp_lookup) { |id| OpenStruct.new(id: id) if id.present? }
    c.define_singleton_method(:scoped_jeevika_vrp_visible?) { |vrp| vrp&.id == "12" }
    c.define_singleton_method(:jeevika_jankar_bill_record_visible?) { |_| raise "Approval access is unrelated to completed payments" }
    assert c.send(:jeevika_completed_payment_item_visible?, { "jeevika_jankar_id" => "12" })
    refute c.send(:jeevika_completed_payment_item_visible?, { "jeevika_jankar_id" => "13" })
    refute c.send(:jeevika_completed_payment_item_visible?, {})
  end

  def test_bill_list_batches_each_month_and_preserves_process_summary
    c = controller
    calls = []
    c.instance_variable_set(:@jeevika_jankar_target_summary, { original: true })
    c.define_singleton_method(:jeevika_jankar_bill_rows) do |vrp_id:, month_name:, totals_only:|
      raise "Bill list should only load totals" unless totals_only
      calls << [vrp_id, month_name]
      @jeevika_jankar_target_summary = vrp_id.split(",").to_h do |id|
        [id, { month_name.downcase => { target: id.to_i, achievement: 1 } }]
      end
    end
    bills = [["12", "July"], ["13", "July"], ["12", "August"]].map do |id, month|
      OpenStruct.new(data: { "select_vrp" => id, "bill_month" => month })
    end
    c.send(:preload_jeevika_bill_process_totals, bills)
    assert_equal [["12,13", "July"], ["12", "August"]], calls
    assert_equal 13, c.send(:jeevika_jankar_bill_total_target, bills[1])
    assert_equal 1, c.send(:jeevika_jankar_bill_total_achievement, bills[2])
    assert_equal({ original: true }, c.instance_variable_get(:@jeevika_jankar_target_summary))
    refute c.instance_variable_get(:@bill_list_batch_totals)
  end

  def test_monthly_counts_skip_unused_training_record_loading
    c = controller
    c.define_singleton_method(:training_participation_targets_for_dashboard) { |**_| [] }
    c.define_singleton_method(:training_participation_dashboard_counts_from_sql) { |**_| { total: 7 } }
    c.define_singleton_method(:dashboard_training_participation_records) { |**_| raise "Unused training records loaded" }
    assert_equal({ total: 7 }, c.send(:training_participation_dashboard_counts_uncached, month_name: "July", fcoc_name: nil))
  end
end
