require "minitest/autorun"
require "active_support/all"
require "ostruct"
require_relative "../app/services/farmer_target_api"

class FarmerTrainingSelectionUnitTest < Minitest::Test
  def setup
    @api = FarmerTargetApi.new(current_app_user: {}, module_slug: "training-form")
    @target = OpenStruct.new(afl_ids: [], month_name: "June", ics_name: "ICS", village_name: "Village",
      main_activity_name: "Farmers' Training", activity_name: "Introduction")
    target = @target
    @api.define_singleton_method(:model_ready?) { |_| true }
    @api.define_singleton_method(:training_target_scope) { [target] }
    @api.define_singleton_method(:completed_training_farmer_ids_for) { |_, _| ["2"] }
    @api.define_singleton_method(:mapped_training_farmer_ids) { |_| ["1", "2"] }
    @api.define_singleton_method(:training_location_farmer_ids) { |_| ["3", "2"] }
    @data = { "month" => "June", "ics_block" => "ICS", "gram_name" => "Village",
      "main_activity_type" => "Training", "main_activity" => "Farmers' Training", "sub_activity" => "Introduction" }
  end

  def test_all_activity_resolution_paths_preserve_available_farmers
    training = { main_activity_type: "Training" }
    [
      [{ "farmers' training" => training }, {}],
      [{ "introduction" => training }, {}],
      [{}, { "introduction" => training }],
      [{}, { "farmers' training" => training }]
    ].each do |main, sub|
      @api.define_singleton_method(:main_activity_settings) { main }
      @api.define_singleton_method(:sub_activity_settings_for) { |_| sub }
      assert_equal ["1"], @api.send(:pending_training_farmer_ids_for, @data)
    end
  end

  def test_farmer_fallbacks_and_completed_exclusion
    @api.define_singleton_method(:main_activity_settings) { { "farmers' training" => { main_activity_type: "Training" } } }
    @api.define_singleton_method(:sub_activity_settings_for) { |_| {} }
    assert_equal ["1"], @api.send(:pending_training_farmer_ids_for, @data)
    @api.define_singleton_method(:mapped_training_farmer_ids) { |_| [] }
    assert_equal ["3"], @api.send(:pending_training_farmer_ids_for, @data)
    @target.afl_ids = ["4", "2"]
    assert_equal ["4"], @api.send(:pending_training_farmer_ids_for, @data)
    @data["month"] = "July"
    assert_empty @api.send(:pending_training_farmer_ids_for, @data)
  end
end
