require "test_helper"

class FarmerTrainingPerformanceTest < ActiveSupport::TestCase
  test "empty farmer submission preserves validation errors without loading farmer profiles" do
    api = FarmerTargetApi.new(current_app_user: { "user_type" => "admin", "name" => "Trainer", "mobile_no" => "9876543210" }, module_slug: "training-form")
    api.define_singleton_method(:preload_training_farmers_for_targets!) { |_| raise "unused farmer profiles" }
    api.define_singleton_method(:pending_training_farmer_ids_for) { |_| raise "empty selection needs no completion scan" }
    result = api.create({ "month" => "August", "ics_block" => "ICS", "gram_name" => "Village", "main_activity" => "Farmers' Training", "sub_activity" => "Soil", "selected_farmers" => "[]" })
    refute result[:success]
    assert_includes result[:errors], "Target Farmers select karein."
    assert result[:errors].any? { |error| error.include?("Training Register Upload") }
    assert result[:errors].any? { |error| error.include?("Training Photo Upload") }
  end

  test "indexed farmer lookup retains numeric and string JSON IDs" do
    records = [["42"], [42], ["142"], []].map { |ids| ModuleRecord.create!(module_slug: "training-form", data: { "selected_farmer_ids" => ids }) }
    scope = ModuleRecord.where(id: records.map(&:id))
    selected = ModulesController.new.send(:training_record_scope_for_farmer_ids, scope, ["42"])
    assert_equal records.first(2).map(&:id).sort, selected.pluck(:id).sort
  end

  test "an empty supplied achievement index is authoritative" do
    c = ModulesController.new
    c.define_singleton_method(:approved_other_target_achievement_index) { raise "repeated index calculation" }
    c.define_singleton_method(:jeevika_jankar_activity_setting_for) { |*_| { main_activity_type: "Other" } }
    c.define_singleton_method(:vrp_target_bill_completed_quantity) { |*_| 0 }
    target = TargetMapping.new(id: 123, target_quantity: 0)
    # No fallback index query should occur even when the supplied index is empty.
    assert_equal 0, c.send(:vrp_target_completed_quantity, target, [], activity_settings: {}, sub_activity_settings: {}, other_target_achievement_index: {})
  end
end
