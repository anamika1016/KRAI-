require "test_helper"

class OtherTargetDashboardProgressTest < ActiveSupport::TestCase
  # The box totals the saved Other Target entries for the selected month (see
  # dashboard_other_target_entry_rows), so an entry filed against an office
  # outside the project, or against another month, must stay out of the total.
  def other_target_entry(fco_name:, month:, target:, achievement:, activity: "Farmers WhatsApp Groups")
    ModuleRecord.create!(module_slug: "other-target", data: {
      "fcoc_name" => fco_name, "month" => month, "main_activity" => activity,
      "sub_activity" => "Group", "target" => target.to_s, "achievement" => achievement.to_s,
      "approval_status" => "Approved"
    })
  end

  def other_totals_for(month)
    c = ModulesController.new
    c.params = ActionController::Parameters.new(month: month)
    c.instance_variable_set(:@dashboard_month_filter_value, month)
    c.send(:dashboard_other_activity_totals)
  end

  test "Other cards count saved entries for the month only in supported FCOs" do
    other_target_entry(fco_name: "FCO-C Sausar", month: "August", target: 2, achievement: 2)
    other_target_entry(fco_name: "FCO-C Turekela", month: "August", target: 2, achievement: 2)
    other_target_entry(fco_name: "Nowhere Office", month: "August", target: 9, achievement: 9)
    other_target_entry(fco_name: "FCO-C Sausar", month: "September", target: 7, achievement: 7)

    totals = other_totals_for("August")
    assert_equal 4, totals[:mapped_farmer]
    assert_equal 4, totals[:achievement_farmer]
    assert_equal 0, totals[:pending_farmer]
    assert_equal 100.0, totals[:achieved]
    assert_equal 1, totals[:main_major_work_indicator]
  end

  test "Other cards include an entry whose achievement matches its target" do
    other_target_entry(fco_name: "FCO-C Sausar", month: "August", target: 1, achievement: 1,
      activity: "Farmers WhatsApp Groups")

    totals = other_totals_for("August")
    assert_equal 1, totals[:mapped_farmer]
    assert_equal 1, totals[:achievement_farmer]
    assert_equal 0, totals[:pending_farmer]
    assert_equal 100.0, totals[:achieved]
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
