require "minitest/autorun"
require "active_support/all"
require "rails"
require "ostruct"
require_relative "../app/services/farmer_target_api"

class FarmerTrainingSelectionUnitTest < Minitest::Test
  def setup
    Rails.logger ||= Logger.new(File::NULL)
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

  def test_completed_and_unmapped_selections_have_specific_errors
    @api.define_singleton_method(:main_activity_settings) { { "farmers' training" => { main_activity_type: "Training" } } }
    @api.define_singleton_method(:sub_activity_settings_for) { |_| {} }
    assert_empty @api.send(:training_farmer_selection_errors, @data, ["1"])
    errors = @api.send(:training_farmer_selection_errors, @data, ["1", "2", "99"])
    assert_equal 2, errors.size
    assert errors.any? { |error| error.include?("1 selected farmer(s)") && error.include?("pehle se saved hai") }
    assert errors.any? { |error| error.include?("1 selected farmer(s)") && error.include?("mapped nahi hain") }
    refute_includes errors, "Target Farmers select karein."
  end

  def test_normalization_preserves_all_six_submitted_farmer_ids
    ids = %w[142694 142699 142697 142781 142782 142702]
    @api.define_singleton_method(:normalize_target_form_staff_fields!) { |_| }
    @api.define_singleton_method(:training_trainer_defaults) { ["Trainer", "1234567890"] }
    @api.define_singleton_method(:training_target_match) { |_| nil }
    @api.define_singleton_method(:training_farmer_names) { |_| [] }
    @api.define_singleton_method(:pending_training_farmer_ids_for) { |*_| raise "Normalization must not erase selections" }
    data = @api.send(:normalize_training_form_data, @data.merge("selected_farmer_ids" => ids, "trainee_department" => "FCO-C Sausar"))
    assert_equal ids, data["selected_farmer_ids"]
    assert_equal "6", data["farmer_count"]
  end
end
