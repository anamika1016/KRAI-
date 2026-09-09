require "test_helper"

class CcJjWorkStatusReportTest < ActiveSupport::TestCase
  test "one pending farmer makes the JJ and shared CC red while list retains unmapped farmers" do
    vrps = [build_vrp("Pending JJ"), build_vrp("Completed JJ")]
    vrps.each { |vrp| vrp.cluster_incharge = "Shared CC"; vrp.save!(validate: false) }
    farmers = 5.times.map { |i| Afl.create!(fco_id: "1004", fpo_id: "test", fpo_name: "Test FPO", farmer_name: "Farmer #{i}") }
    targets = []
    [[vrps[0], farmers.take(2), "Farmers' Training"], [vrps[1], [farmers[2]], "Farmers' Training"], [vrps[0], [farmers[3]], "Other"]].each do |vrp, mapped, activity|
      targets << TargetMapping.create!(vrp: vrp, fco_id: "1004", ics_id: "1", village_id: "1", month_name: "August",
        main_activity_name: activity, activity_name: "Activity", target_quantity: 1, afl_ids: mapped.map(&:id))
    end
    ModuleRecord.create!(module_slug: "training-form", data: { month: "August", main_activity: "Farmers' Training",
      selected_farmer_ids: [farmers[0].id.to_s, farmers[2].id.to_s], cluster_coordinator_name: "CC", agronomist_name: "Agronomist" })
    ModuleRecord.create!(module_slug: "training-form", data: { month: "July", main_activity: "Farmers' Training", selected_farmer_ids: [farmers[1].id.to_s] })
    calculator = ModulesController.new
    calculator.define_singleton_method(:dashboard_global_view_user?) { true }
    calculator.define_singleton_method(:dashboard_scoped_training_sql) do |sql|
      sql.gsub("public.target_mappings", "(#{TargetMapping.where(id: targets.map(&:id)).to_sql})")
        .gsub("public.afls", "(#{Afl.where(id: farmers.map(&:id)).to_sql})")
    end
    farmers << Afl.create!(fco_id: "1006", fpo_name: "Second FCO", farmer_name: "Turekela Farmer")
    targets << TargetMapping.create!(vrp: vrps.last, fco_id: "Turekela", ics_id: "1", village_id: "1", month_name: "July",
      main_activity_name: "Farmers' Training", activity_name: "Activity", target_quantity: 1, afl_ids: [farmers.last.id])
    farmers << Afl.create!(fco_id: "1009", fpo_name: "Excluded FCO", farmer_name: "Other Farmer")
    targets << TargetMapping.create!(vrp: vrps.last, fco_id: "1009", ics_id: "1", village_id: "1", month_name: "August",
      main_activity_name: "Farmers' Training", activity_name: "Activity", target_quantity: 1, afl_ids: [farmers.last.id])
    all_fcos = CcJjWorkStatusReport.new(calculator: calculator, month: "August")
    assert_equal ["1004", "1006"], all_fcos.summary.map { |row| row["fco_id"] }.uniq.sort
    assert_equal "August · Sausar and Turekela", all_fcos.caption
    excluded = CcJjWorkStatusReport.new(calculator: calculator, month: "August", fco: "1009")
    assert_empty excluded.summary
    assert_empty excluded.rows
    calculator.request = ActionDispatch::TestRequest.create
    calculator.params = ActionController::Parameters.new(month: "July", fcoc: "Turekela")
    filtered = CcJjWorkStatusReport.new(calculator: calculator)
    assert_equal "July · Turekela", filtered.caption
    assert_equal ["1006"], filtered.summary.map { |row| row["fco_id"] }.uniq
    assert_equal ["1006"], filtered.rows.map { |row| row["fco_id"] }.uniq
    calculator.params = ActionController::Parameters.new(month: "August", fcoc: "Sausar")
    assert_equal ["1004"], CcJjWorkStatusReport.new(calculator: calculator).rows.map { |row| row["fco_id"] }.uniq
    calculator.params = ActionController::Parameters.new
    calculator.request = ActionDispatch::TestRequest.create
    calculator.params = ActionController::Parameters.new(month: "July", fcoc: "Turekela")
    filtered = CcJjWorkStatusReport.new(calculator: calculator)
    assert_equal "July · Turekela", filtered.caption
    assert_equal ["1006"], filtered.summary.map { |row| row["fco_id"] }.uniq
    assert_equal "Completed JJ", filtered.rows.first["vrp_name"]
    calculator.params = ActionController::Parameters.new
    VrpIcsMapping.create!(vrp_id: vrps.last.id, fco_id: "1006", ics_id: "1", village_id: "1", afl_ids: [farmers.find { |farmer| farmer.fco_id == "1006" }.id])
    august_assignment = CcJjWorkStatusReport.new(calculator: calculator, month: "August", fco: "1006").rows.first
    assert_equal "Completed JJ", august_assignment["vrp_name"]
    assert_equal "Shared CC", august_assignment["cluster_incharge"]
    assert_equal 1, august_assignment["No Activity Mapping"]
    assert_equal 0, august_assignment["Red"]
    july = CcJjWorkStatusReport.new(calculator: calculator, month: "July", fco: "1006")
    assert_equal ["1006"], july.summary.map { |row| row["fco_id"] }
    assert_equal "Completed JJ", july.rows.first["vrp_name"]
    assert_equal "Shared CC", july.rows.first["cluster_incharge"]
    assert_equal 1, july.rows.first["Red"]
    assert_equal ["1004", "1006"], CcJjWorkStatusReport.new(calculator: calculator, month: "August").rows.map { |row| row["fco_id"] }.uniq.sort
    report = CcJjWorkStatusReport.new(calculator: calculator, month: "August", fco: "1004")
    red = report.summary.find { |row| row["status"] == "Red" }
    completed = report.summary.find { |row| row["status"] == "Completed" }
    assert_equal 1, red["toatl_cc"]
    assert_equal 1, red["toatl_jj"]
    assert_equal 1, red["red_farmer"]
    assert_equal 0, completed["toatl_cc"]
    assert_equal 1, completed["toatl_jj"]
    assert_equal 5, report.rows.sum { |row| row["total_farmer"] }
    { "No Activity Mapping" => 1, "No Training Mapping" => 1, "Training Mapped But No Entry" => 1,
      "Training Entry Done" => 2, "Red" => 1, "Completed" => 2,
      "Cluster Coordinator Involved" => 2, "Agronomist Involved" => 2 }.each do |key, count|
      assert_equal count, report.rows.sum { |row| row[key] }, key
    end
  end

  private

  def build_vrp(name)
    Vrp.new(name: name, aadhar_no: "123456789012", account_no: "1234", address: "Test", branch: "Test",
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current, email: "#{SecureRandom.hex(4)}@example.com",
      experience_in_years: 1, father_husband_name: "Test", gender: :male, ifsc_code: "SBIN0001234",
      mobile_no: "9876543210", office_detail_id: 1, to_office_detail_id: 1)
  end

end
