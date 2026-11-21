require "test_helper"

class BillTotalsLoadingTest < ActiveSupport::TestCase
  test "bill totals retain grouped training and other achievements without unused weekly breakdowns" do
    targets = 3.times.map do |i|
      TargetMapping.new(id: i + 1, vrp_id: 7, month_name: "August", fco_id: "office",
        village_id: "village", ics_id: "ics", main_activity_name: "Training", activity_name: "Activity #{i}",
        mapping_group_key: i < 2 ? "combined" : nil, target_quantity: 5, afl_ids: i < 2 ? %w[1 2 3] : [])
    end
    build = lambda do
      controller = ModulesController.new
      calls = Hash.new(0)
      controller.define_singleton_method(:jeevika_jankar_main_activity_settings) { [] }
      controller.define_singleton_method(:jeevika_jankar_sub_activity_settings) { |_| [] }
      controller.define_singleton_method(:approved_other_target_achievement_index) { { "2" => { completed: 2 }, "3" => { completed: 4 } } }
      controller.define_singleton_method(:training_participation_existing_farmer_id_set) { |_| Set.new(%w[1 2 3]) }
      controller.define_singleton_method(:vrp_dashboard_completed_farmer_ids_for_target) do |target|
        calls[:individual] += 1
        target.id < 3 ? %w[1] : []
      end
      controller.define_singleton_method(:jeevika_jankar_activity_setting_for) do |target, *_|
        { main_activity_type: target.id == 1 ? "Training" : "Other" }
      end
      controller.define_singleton_method(:vrp_target_completed_quantity) { |target, *_args, **_kwargs| target.id == 2 ? 2 : 4 }
      controller.define_singleton_method(:training_weekly_achievement_farmer_ids) do |*_|
        calls[:weekly] += 1
        [%w[1], [], [], []]
      end
      controller.define_singleton_method(:dashboard_training_form_total_farmer_count) { |rows, _| rows.any? ? 2 : 0 }
      controller.define_singleton_method(:dashboard_training_form_completed_farmer_ids) { |rows, _| rows.any? ? %w[1 2] : [] }
      [controller, calls]
    end
    original, original_calls = build.call
    summary, summary_calls = build.call
    full_rows = original.send(:vrp_dashboard_target_progress_rows, targets, [])
    total_rows = summary.send(:vrp_dashboard_target_progress_rows, targets, [], totals_only: true)
    fields = %i[target_mapping_id target_mapping_ids month target completed pending assigned_farmer_ids completed_farmer_ids]
    assert_equal full_rows.map { |row| row.slice(*fields) }, total_rows.map { |row| row.slice(*fields) }
    assert_equal [2.0, 4.0], total_rows.map { |row| row[:completed] }
    assert_equal 3, original_calls[:weekly]
    assert_equal 0, summary_calls[:weekly]
    assert_equal 3, original_calls[:individual]
    assert_equal 2, summary_calls[:individual], "Other activity calculations must still run"
  end
end
