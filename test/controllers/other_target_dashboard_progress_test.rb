require "test_helper"

class OtherTargetDashboardProgressTest < ActiveSupport::TestCase
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
