require "test_helper"

# The Other Target form may only offer work that is set up as Main Major Work
# Indicator Type = "Other". A Training target leaking in also drags its ICS,
# Village and activity names into the form's dropdowns.
class OtherTargetExcludesTrainingTest < ActiveSupport::TestCase
  setup do
    @vrp = Vrp.new(name: "Aanjana Uikey", father_husband_name: "Father", gender: :female,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "8819885922", email: "aanjana@example.test", fcoc: "Sausar",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    @vrp.save!(validate: false)

    # A genuine "Other" indicator.
    ModuleRecord.create!(module_slug: "add-activity-group", data: {
      "main_activity_name" => "Seed Distribution", "main_activity_type" => "Other"
    })
    # The Training indicator happens to have a sub-activity with the very same
    # name as the Other indicator above -- the collision that caused the leak.
    ModuleRecord.create!(module_slug: "add-vrp-activity", data: {
      "main_activity" => "Farmers' Training", "sub_activity_name" => "Seed Distribution"
    })

    @training_target = build_target("Farmers' Training", "Seed Distribution", "Training ICS", "Training Village")
    @other_target = build_target("Seed Distribution", "Kit Handover", "Other ICS", "Other Village")
  end

  test "a Training target does not reach the Other Target form" do
    topics = mappings.map { |row| row[:training_topic] }

    refute_includes topics, "Farmers' Training", "Training indicator leaked into the Other Target form"
    assert_includes topics, "Seed Distribution", "the genuine Other indicator must still be offered"
  end

  test "ICS options only come from Other indicators" do
    ics = mappings.map { |row| row[:ics] }

    refute_includes ics, "Training ICS", "ICS of a Training indicator must not be offered"
    assert_includes ics, "Other ICS"
  end

  private

  def build_target(main_activity, sub_activity, ics, village)
    target = TargetMapping.new(vrp: @vrp, fco_id: "1004", fco_name: "Sausar",
      ics_id: ics.parameterize, ics_name: ics, village_id: village.parameterize, village_name: village,
      month_name: "September", main_activity_name: main_activity, activity_name: sub_activity,
      target_quantity: 10)
    target.save!(validate: false)
    target
  end

  def mappings
    controller = ModulesController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new
    controller.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
    controller.send(:seed_distribution_target_mappings)
  end
end
