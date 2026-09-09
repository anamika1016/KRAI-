require "test_helper"

class DemonstrationMethodReportTest < ActiveSupport::TestCase
  setup do
    @vrp = build_vrp("Demo VRP")
    @vrp.save!(validate: false)
    @second = build_vrp("Zero entries")
    @second.save!(validate: false)
    @targets = [target(@vrp, 3), target(@vrp, 4), target(@second, nil)]
    target(@vrp, 99, "July")
    [" General Training/Meeting ", "INPUT DEMO INM", "Input Demo PM", "FFS", "Other"].each do |method|
      entry(@vrp, method)
    end
    entry(@vrp, "FFS", "July")
    entry(@second, "FFS", "July")
  end

  test "sums repeated targets without multiplying method entries and includes zero entries" do
    report = DemonstrationMethodReport.new(targets: @targets)
    assert_equal 2, report.rows.size
    first = report.rows.find { |row| row["vrp_id"] == @vrp.id }
    assert_equal 7, first["OPG Target"]
    DemonstrationMethodReport::METRICS.drop(1).each { |key| assert_equal 1, first[key] }
    zero = report.rows.find { |row| row["vrp_id"] == @second.id }
    DemonstrationMethodReport::METRICS.each { |key| assert_equal 0, zero[key] }
    assert_equal 1, report.summary.size
    assert_equal 7, report.summary.first["OPG Target"]
    assert_equal 1, report.summary.first["FFS"]
  end

  test "only includes supplied target scope and selected month" do
    report = DemonstrationMethodReport.new(targets: [@targets.last])
    assert_equal [@second.id], report.rows.map { |row| row["vrp_id"] }
    assert_equal 0, report.summary.first["FFS"]
    assert_empty DemonstrationMethodReport.new(targets: @targets, month: "July").rows
    assert_empty DemonstrationMethodReport.new(targets: []).summary
  end

  test "summary trims creator IDs while view list uses the supplied exact ID join" do
    ModuleRecord.create!(module_slug: "training-form", data: { created_by_id: " #{@vrp.id} ", month: "August", training_method: "FFS" })
    report = DemonstrationMethodReport.new(targets: @targets)
    assert_equal 2, report.summary.first["FFS"]
    assert_equal 1, report.rows.find { |row| row["vrp_id"] == @vrp.id }["FFS"]
  end

  private

  def build_vrp(name)
    Vrp.new(name: name, aadhar_no: "123456789012", account_no: "1234", address: "Test", branch: "Test",
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current, email: "#{SecureRandom.hex(4)}@example.com",
      experience_in_years: 1, father_husband_name: "Test", gender: :male, ifsc_code: "SBIN0001234",
      mobile_no: "9876543210", office_detail_id: 1, to_office_detail_id: 1)
  end

  def target(vrp, amount, month = " August ")
    TargetMapping.create!(vrp: vrp, fco_id: "demo", fco_name: "Demo FCO", ics_id: "1", village_id: "1",
      month_name: month, main_activity_name: "Training", activity_name: "Demo", target_quantity: 0, opg_training_target: amount)
  end

  def entry(vrp, method, month = " AUGUST ")
    ModuleRecord.create!(module_slug: "training-form", data: { created_by_id: vrp.id.to_s, month: month, training_method: method })
  end
end
