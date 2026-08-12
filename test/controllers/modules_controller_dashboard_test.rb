require "test_helper"

class ModulesControllerDashboardTest < ActiveSupport::TestCase
  Target = Struct.new(
    :vrp_id, :fco_name, :fco_id, :ics_name, :ics_id, :village_name,
    :village_id, :month_name, :completion_date, :opg_training_target,
    :week_wise_opg_target, :input_demo_inm_target, :input_demo_pm_target,
    :ffs_target, :afl_ids, :main_activity_name, :activity_name,
    keyword_init: true
  )

  test "target record count combines activity rows belonging to one assignment" do
    assignment = {
      vrp_id: 7,
      fco_name: "Sausar",
      ics_name: "ICS 1",
      village_name: "Village 1",
      month_name: "August",
      completion_date: Date.new(2026, 8, 31),
      afl_ids: %w[11 12]
    }
    targets = [
      Target.new(**assignment, main_activity_name: "Training", activity_name: "Activity A"),
      Target.new(**assignment, main_activity_name: "Training", activity_name: "Activity B"),
      Target.new(**assignment.merge(month_name: "September"), main_activity_name: "Training", activity_name: "Activity A")
    ]

    assert_equal 2, ModulesController.new.send(:dashboard_target_record_count, targets)
  end

  test "target record count includes all assignments dynamically" do
    targets = 101.times.map do |index|
      Target.new(
        vrp_id: index + 1,
        fco_name: "Sausar",
        ics_name: "ICS 1",
        village_name: "Village #{index + 1}",
        month_name: "August",
        completion_date: Date.new(2026, 8, 31),
        afl_ids: [index + 1]
      )
    end

    assert_equal 101, ModulesController.new.send(:dashboard_target_record_count, targets)
  end
end
