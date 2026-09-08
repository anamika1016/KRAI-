require "test_helper"

class DashboardIcsFilterTest < ActiveSupport::TestCase
  test "participation and demonstration counts follow ICS month and FCO for admin" do
    first = Afl.create!(farmer_name: "ICS A Farmer", fco_id: "1004", fco: "Sausar", ics_id: "ics-a", ics_name: "ICS A")
    second = Afl.create!(farmer_name: "ICS B Farmer", fco_id: "1004", fco: "Sausar", ics_id: "ics-b", ics_name: "ICS B")
    vrp = Vrp.new(name: "ICS Test JJ", mobile_no: "9876543210", aadhar_no: "123456789012", account_no: "12345", address: "Test", branch: "Test", date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.new(2026, 1, 1), email: "ics-test@example.com", experience_in_years: 1, father_husband_name: "Test", gender: :male, ifsc_code: "TEST0001234", office_detail_id: 0, to_office_detail_id: 0, fcoc: "Sausar")
    vrp.save!(validate: false)
    [first, second].each do |farmer|
      target = TargetMapping.new(vrp_id: vrp.id, village_id: "test-village", month_name: "July", fco_id: "1004", fco_name: "Sausar", ics_id: farmer.ics_id, ics_name: farmer.ics_name,
        main_activity_name: "Farmers' Training", activity_name: "Soil", afl_ids: [farmer.id.to_s], target_quantity: 1)
      target.save!(validate: false)
      ModuleRecord.create!(module_slug: "training-form", data: {
        "month" => "July", "main_activity" => "Farmers' Training", "main_activity_type" => "Training",
        "selected_farmer_ids" => [farmer.id.to_s], "target_mapping_ids" => [target.id.to_s],
        "training_method" => "General Training/Meeting", "trainee_department" => "Sausar"
      })
    end
    ModuleRecord.create!(module_slug: "training-form", data: {
      "month" => "August", "main_activity" => "Farmers' Training", "selected_farmer_ids" => [first.id.to_s]
    })

    c = ModulesController.new
    c.params = ActionController::Parameters.new(ics: "ICS A", month: "July", fcoc: "Sausar")
    c.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
    c.instance_variable_set(:@participation_selected_month, "July")
    c.instance_variable_set(:@participation_fcoc_filter_value, "Sausar")
    assert_equal [first.id], c.send(:dashboard_visible_farmer_scope).pluck(:id)
    assert_equal 1, c.send(:farmer_training_yellow_farmer_count_and_popups, month_name: "July", fcoc_name: "1004").first
    assert_equal 0, c.send(:farmer_training_green_farmer_count_and_popups, month_name: "July", fcoc_name: "1004").first
    assert_equal 1, c.send(:dashboard_training_method_counts)["General Training/Meeting"]
    assert_equal 1, c.send(:dashboard_opg_achievement_count)
    counts = c.send(:training_participation_dashboard_counts_from_sql, month_name: "July", fcoc_name: "Sausar", targets: [])
    assert_equal 1, counts[:total]
    assert_equal 1, counts[:yellow]
  end
end
