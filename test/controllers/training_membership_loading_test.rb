require "test_helper"
require "ostruct"

class TrainingMembershipLoadingTest < ActiveSupport::TestCase
  test "target metadata is reused while shared farmer identities retain merged memberships" do
    controller = ModulesController.new
    targets = [1, 2, 3].map do |id|
      OpenStruct.new(id: id, month_name: "November", fco_name: "Office #{id}",
        main_activity_name: "Training", activity_name: "Activity #{id}",
        vrp: OpenStruct.new(name: "JJ #{id}", fcoc: "FCO", cluster_incharge: "CC"))
    end
    ids = { 1 => %w[11 12], 2 => %w[13], 3 => [] }
    calls = Hash.new(0)
    controller.define_singleton_method(:training_participation_existing_farmer_id_set) { |_| Set.new(%w[11 12 13]) }
    controller.define_singleton_method(:training_farmers_by_id) { |_| {} }
    controller.define_singleton_method(:training_participation_target_farmer_ids) { |target| ids.fetch(target.id) }
    controller.define_singleton_method(:training_participation_target_farmer_key) { |id| id == "13" ? "11" : id }
    %i[target_ics_label target_village_label target_mapping_registered_by_name].each do |method|
      controller.define_singleton_method(method) do |target|
        calls[[method, target.id]] += 1
        "#{method} #{target.id}"
      end
    end
    controller.define_singleton_method(:training_participation_target_activity_keys) do |target|
      calls[[:activities, target.id]] += 1
      ["activity-#{target.id}"]
    end
    controller.define_singleton_method(:training_participation_month_open?) { |_| true }

    rows = controller.send(:training_participation_target_memberships, targets).values
    assert_equal 2, rows.size
    shared = rows.find { |row| row[:farmer_id] == "11" }
    assert_equal "11, 13", shared[:source_farmer_ids]
    assert_equal "JJ 1, JJ 2", shared[:vrp]
    assert_equal "Office 1, FCO, Office 2", shared[:fcoc]
    assert_equal "Activity 1, Activity 2", shared[:sub_activities]
    assert_equal 2, shared[:assigned_activity_count]
    assert shared[:pending_available]
    assert_equal [1] * 8, calls.values
    assert calls.keys.none? { |_, id| id == 3 }, "Empty targets must not resolve labels"
  end
end
