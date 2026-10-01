require "test_helper"

# Achievement against an assigned Other target is cumulative. A 36 target filled
# with 36 must not accept a second entry; filled with 30 it must still accept 6.
class OtherTargetAchievementCapTest < ActiveSupport::TestCase
  setup do
    @vrp = Vrp.new(name: "Cap JJ", father_husband_name: "Father", gender: :female,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876500701", email: "cap-jj@example.test", fcoc: "Sausar",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    @vrp.save!(validate: false)

    ModuleRecord.create!(module_slug: "add-activity-group", data: {
      "main_activity_name" => "Internal Inspection", "main_activity_type" => "Other"
    })

    @target = TargetMapping.new(vrp: @vrp, fco_id: "1004", fco_name: "Sausar",
      ics_id: "cap-ics", ics_name: "Cap ICS", village_id: "cap-village", village_name: "Cap Village",
      month_name: "September", main_activity_name: "Internal Inspection",
      activity_name: "Internal Inspection Documentation", target_quantity: 36)
    @target.save!(validate: false)
  end

  test "an entry within the remaining amount is accepted" do
    assert_empty achievement_errors(30)
  end

  test "the exact remaining amount is accepted after a partial entry" do
    submit!(30)

    assert_empty achievement_errors(6), "6 should still be allowed after 30 of 36"
  end

  test "an entry beyond the remaining amount is rejected" do
    submit!(30)
    errors = achievement_errors(10)

    assert errors.any? { |e| e.include?("6") }, "expected the remaining 6 to be named, got: #{errors.inspect}"
  end

  test "nothing more is accepted once the target is fully achieved" do
    submit!(36)
    errors = achievement_errors(1)

    assert errors.any? { |e| e.include?("already submit") }, "expected a fully-achieved message, got: #{errors.inspect}"
  end

  test "editing an existing entry does not count itself twice" do
    record = submit!(30)

    assert_empty achievement_errors(36, editing: record), "editing to the full 36 should be allowed"
  end

  private

  def payload(achievement)
    {
      "jeevika_jankar_id" => @vrp.id.to_s, "jeevika_jankar_name" => @vrp.name,
      "contact_number" => "9876500701", "month" => "September",
      "ics" => "Cap ICS", "village" => "Cap Village",
      "training_topic" => "Internal Inspection",
      "training_subject" => "Internal Inspection Documentation",
      "main_activity" => "Internal Inspection",
      "sub_activity" => "Internal Inspection Documentation",
      "completion_date" => "2026-09-30", "target" => "36",
      "achievement" => achievement.to_s, "target_mapping_id" => @target.id.to_s
    }
  end

  def submit!(achievement)
    ModuleRecord.create!(module_slug: "other-target", data: payload(achievement))
  end

  def achievement_errors(achievement, editing: nil)
    c = ModulesController.new
    c.request = ActionDispatch::TestRequest.create
    c.params = ActionController::Parameters.new
    c.instance_variable_set(:@slug, "other-target")
    c.instance_variable_set(:@record, editing)
    c.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
    c.send(:seed_distribution_target_error_messages, payload(achievement))
  end
end
