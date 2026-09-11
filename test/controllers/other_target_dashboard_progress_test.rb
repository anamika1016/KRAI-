require "test_helper"

class OtherTargetDashboardProgressTest < ActiveSupport::TestCase
  test "Other cards count distinct completed farmers per month activity only in supported FCOs" do
    farmers = 3.times.map { |i| Afl.create!(farmer_name: "Other farmer #{i}") }
    next_id = 10000
    build = lambda do |fco, activity, ids|
      TargetMapping.new(id: (next_id += 1), vrp_id: 1, fco_id: fco,
        ics_id: "ICS", village_id: "V", month_name: "August", main_activity_name: "Farmers WhatsApp Groups",
        activity_name: activity, target_quantity: ids.size, afl_ids: ids)
    end
    ids = farmers.map { |f| f.id.to_s }
    targets = [build.call("1004", "Group", ids.first(2)), build.call("1006", "Group", ids.last(2)),
      build.call("1004", "Second activity", ids.first(1)), build.call("9999", "Group", ids)]
    c = ModulesController.new
    c.define_singleton_method(:preload_training_farmers_for_targets!) { |_| }
    c.define_singleton_method(:vrp_dashboard_target_progress_rows) do |rows, _|
      rows.map { |target| { target: target.afl_ids.size, completed: target.afl_ids.size,
        assigned_farmer_ids: target.afl_ids, completed_farmer_ids: target.afl_ids } }
    end
    assert_equal({ target: 4, completed: 4, pending: 0 }, c.send(:dashboard_other_activity_totals, targets + [targets.first]))
  end

  test "Other cards include existing farmer completion evidence without a numeric achievement" do
    farmer = Afl.create!(farmer_name: "Completed WhatsApp farmer")
    target = TargetMapping.new(id: 702, vrp_id: 1, fco_id: "1004", month_name: "August",
      main_activity_name: "Farmers WhatsApp Groups", activity_name: "Village Group", target_quantity: 1, afl_ids: [farmer.id])
    ModuleRecord.create!(module_slug: "other-target", data: {
      "target_mapping_id" => "702", "month" => "August", "selected_farmer_ids" => [farmer.id.to_s]
    })
    c = ModulesController.new
    c.params = ActionController::Parameters.new
    c.define_singleton_method(:jeevika_jankar_main_activity_settings) { [] }
    c.define_singleton_method(:jeevika_jankar_sub_activity_settings) { |_| [] }
    c.define_singleton_method(:jeevika_jankar_activity_setting_for) { |*_| { main_activity_type: "Other" } }
    c.define_singleton_method(:completed_training_farmer_ids_for) { |*_| [] }
    c.define_singleton_method(:training_weekly_achievement_farmer_ids) { |*_| [[], [], [], []] }
    assert_equal({ target: 1, completed: 1, pending: 0 }, c.send(:dashboard_other_activity_totals, [target]))
  end

  test "manual Other Target achievement survives a missing activity master" do
    target = TargetMapping.new(id: 701, month_name: "August", main_activity_name: "Legacy Other", activity_name: "WhatsApp", target_quantity: 40, afl_ids: [])
    controller = ModulesController.new
    controller.define_singleton_method(:jeevika_jankar_main_activity_settings) { [] }
    controller.define_singleton_method(:jeevika_jankar_sub_activity_settings) { |_| [] }
    controller.define_singleton_method(:jeevika_jankar_activity_setting_for) { |*_| nil }
    controller.define_singleton_method(:other_target_candidate_targets) { [target] }
    record = ModuleRecord.create!(module_slug: "other-target", data: {
      "target_mapping_id" => "701", "month" => "August", "achievement" => "30"
    })
    controller.define_singleton_method(:vrp_dashboard_completed_farmer_ids_for_target) { |_| [] }
    controller.define_singleton_method(:training_weekly_achievement_farmer_ids) { |*_| [[], [], [], []] }
    controller.define_singleton_method(:dashboard_training_form_total_farmer_count) { |*_| 0 }
    controller.define_singleton_method(:dashboard_training_form_completed_farmer_ids) { |*_| [] }
    rows = controller.send(:vrp_dashboard_target_progress_rows, [target], [])
    assert_equal 30, rows.first[:completed]
    assert_equal 10, rows.first[:pending]
    assert_equal({ assigned: 40.0, achieved: 30.0, pending: 10.0 }, controller.send(:vrp_dashboard_target_totals, rows))
    record.update!(data: record.data.merge("achievement" => "40"))
    rows = controller.send(:vrp_dashboard_target_progress_rows, [target], [])
    assert_equal 40, rows.first[:completed]
    assert_equal 0, rows.first[:pending]
    record.update!(data: record.data.merge("approval_status" => "Rejected"))
    assert_empty controller.send(:approved_other_target_achievement_index)
  end
end
