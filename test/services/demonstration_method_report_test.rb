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

  test "de-duplicates targets per village and splits method entries into record and farmer counts" do
    report = DemonstrationMethodReport.new(targets: @targets)
    assert_equal 2, report.rows.size
    first = report.rows.find { |row| row["vrp_id"] == @vrp.id }
    assert_equal "4 / 4", first["OPG Target / Done"]
    assert_equal "4 / 1", first["General Training/Meeting"]
    assert_equal "0 / 1", first["Input Demo INM"]
    assert_equal "0 / 1", first["Input Demo PM"]
    assert_equal "0 / 1", first["FFS"]
    assert_equal "Green", first["Status"]

    zero = report.rows.find { |row| row["vrp_id"] == @second.id }
    assert_equal "0 / 0", zero["OPG Target / Done"]
    assert_equal "0 / 0", zero["General Training/Meeting"]
    assert_equal "Green", zero["Status"]

    assert_equal 1, report.summary.size
    assert_equal 4, report.summary.first["OPG Target"]
    assert_equal 1, report.summary.first["FFS"]
  end

  test "only includes supplied target scope and selected month" do
    report = DemonstrationMethodReport.new(targets: [@targets.last])
    assert_equal [@second.id], report.rows.map { |row| row["vrp_id"] }
    assert_equal 0, report.summary.first["FFS"]
    assert_empty DemonstrationMethodReport.new(targets: @targets, month: "July").rows
    assert_empty DemonstrationMethodReport.new(targets: []).summary
  end

  test "both dashboard panels share unique sessions and the same visible JJ scope" do
    duplicate_mapping = @targets.first.dup
    duplicate_mapping.assign_attributes(fco_id: "another-fco", fco_name: "Historical office")
    duplicate_mapping.save!
    targets = @targets + [duplicate_mapping]

    { nil => 4, "" => 4, "all" => 4, "August" => 4, "July" => 0 }.each do |month, expected|
      shared = DemonstrationMethodReport.new(targets: targets, month: month, visible_vrp_ids: [@vrp.id])
      cc = CcDashboardReport.new(targets: targets, vrps: [@vrp], month: month, demonstration_report: shared)
      web = ModulesController.new
      web.request = ActionDispatch::TestRequest.create
      web.instance_variable_set(:@demonstration_method_report, shared)
      cards = web.send(:demonstration_method_cards)
      opg = cards.find { |card| card[:title] == "OPG Training Target" }[:value].split("/").last.to_i
      method_total = cards.select { |card| ["General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS Exposure"].include?(card[:title]) }
        .sum { |card| card[:value].split("/").last.to_i }
      assert_equal expected, opg, "period=#{month.inspect}"
      assert_equal expected, method_total
      assert_equal expected, cc.jj_achievement
      assert_equal expected, cc.rows.sum { |row| row["Total OPG JJ Achievement"] }
    end

    assert_equal 0, DemonstrationMethodReport.new(targets: targets, month: "all", visible_vrp_ids: []).achievement_totals.values.sum
    assert_equal 0, DemonstrationMethodReport.new(targets: [], month: "all").achievement_totals.values.sum
    entry(@vrp, "Input Demo PM", "September")
    refreshed = DemonstrationMethodReport.new(targets: targets, month: "all", visible_vrp_ids: [@vrp.id])
    assert_equal 4, refreshed.achievement_totals.values.sum, "an unmapped month must not inflate All Months"
    september = target(@vrp, 1, "September")
    refreshed = DemonstrationMethodReport.new(targets: targets + [september], month: "all", visible_vrp_ids: [@vrp.id])
    assert_equal 5, refreshed.achievement_totals.values.sum
  end

  test "FCO labels sharing an ID do not multiply summary achievements" do
    @targets.last.update!(fco_name: "Demo FCO legacy label")
    entry(@second, "General Training/Meeting")
    ["all", "August"].each do |month|
      report = DemonstrationMethodReport.new(targets: @targets, month: month)
      expected_rows = report.rows.sum { |row| row["OPG Achievement"].to_i }
      summary_done = report.summary.sum do |row|
        ["General Training/Meeting Done", "Input Demo INM Done", "Input Demo PM Done", "FFS Done"].sum { |key| row[key].to_i }
      end
      assert_equal 5, expected_rows
      assert_equal expected_rows, summary_done
      cc = CcDashboardReport.new(targets: @targets, vrps: [@vrp, @second], month: month)
      assert_equal summary_done, cc.jj_achievement
      assert_equal 2, report.summary.size, "keep both existing target groups"
    end
  end

  test "CC OPG achievements exclude sessions without a monthly mapping" do
    [nil, "", "all", "August"].each do |month|
      demo = DemonstrationMethodReport.new(targets: @targets, month: month)
      expected = demo.summary.sum do |row|
        ["General Training/Meeting Done", "Input Demo INM Done", "Input Demo PM Done", "FFS Done"].sum { |key| row[key].to_i }
      end
      cc = CcDashboardReport.new(targets: @targets, vrps: [@vrp, @second], month: month)
      assert_equal expected, cc.jj_achievement, "period=#{month.inspect}"
      assert_equal 4, cc.jj_achievement
      assert_equal cc.jj_achievement, cc.rows.sum { |row| row["OPG Training"].split("/").last.to_i }
    end
    # A JJ outside the supplied mappings still contributes nothing.
    outsider = build_vrp("Outside scope")
    outsider.save!(validate: false)
    entry(outsider, "FFS", "July")
    cc = CcDashboardReport.new(targets: @targets, vrps: [@vrp, @second, outsider], month: "all")
    assert_equal 4, cc.jj_achievement
    assert_equal 0, cc.rows.find { |row| row["JJ Name"] == outsider.name }["Total OPG JJ Achievement"]
  end

  test "summary and view list both trim padded creator IDs" do
    ModuleRecord.create!(module_slug: "training-form", data: { created_by_id: " #{@vrp.id} ", month: "August", training_method: "FFS" })
    report = DemonstrationMethodReport.new(targets: @targets)
    assert_equal 2, report.summary.first["FFS"]
    assert_equal "0 / 2", report.rows.find { |row| row["vrp_id"] == @vrp.id }["FFS"]
  end

  test "relation input preserves report results without instantiating targets" do
    scope = TargetMapping.where(id: @targets.map(&:id)).order(:id).limit(2)
    expected = DemonstrationMethodReport.new(targets: scope.to_a)
    scope = TargetMapping.where(id: @targets.map(&:id)).order(:id).limit(2)
    instantiated = 0
    subscriber = ActiveSupport::Notifications.subscribe("instantiation.active_record") do |*args|
      payload = args.last
      instantiated += payload[:record_count] if payload[:class_name] == "TargetMapping"
    end
    report = DemonstrationMethodReport.new(targets: scope)
    assert_equal 0, instantiated
    assert_not scope.loaded?
    assert_equal expected.rows, report.rows
    assert_equal expected.summary, report.summary
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "expanded farmer arrays preserve distinct record and farmer counts including empty arrays" do
    shared = { created_by_id: " #{@vrp.id} ", month: " AUGUST ", training_method: " FFS " }
    ModuleRecord.create!(module_slug: "training-form", data: shared.merge(selected_farmer_ids: ["11", "11", "12", nil, ""]))
    ModuleRecord.create!(module_slug: "training-form", data: shared.merge(selected_farmer_ids: ["12", "13"]))
    ModuleRecord.create!(module_slug: "training-form", data: shared.merge(selected_farmer_ids: []))
    ModuleRecord.create!(module_slug: "training-form", data: shared.merge(created_by_id: "999999", selected_farmer_ids: ["99"]))
    report = DemonstrationMethodReport.new(targets: @targets)
    row = report.rows.find { |item| item["vrp_id"] == @vrp.id }
    assert_equal "0 / 4", row["FFS"]
    assert_equal 4, report.summary.first["FFS"]
    assert_equal "4 / 7", row["OPG Target / Done"]
    assert_equal "0 / 4", DemonstrationMethodReport.new(targets: @targets, month: "all").rows.find { |item| item["vrp_id"] == @vrp.id }["FFS"]
  end

  test "saving a removed CC recalculates achievement without removing training achievement" do
    @targets.first.update!(cc_target: 1)
    ModuleRecord.where(module_slug: "training-form").delete_all
    record = ModuleRecord.create!(module_slug: "training-form", data: {
      "created_by_id" => @vrp.id.to_s, "month" => "August",
      "training_method" => "General Training/Meeting", "cluster_coordinator_name" => "Coordinator"
    })
    report_row = -> { DemonstrationMethodReport.new(targets: @targets, month: "August").rows.find { |row| row["vrp_id"] == @vrp.id } }
    assert_equal "1 / 1", report_row.call["CC TARGET STATUS"]
    ["N/A", "", nil].each do |removed|
      record.update!(data: record.data.merge("cluster_coordinator_name" => removed))
      assert_equal "1 / 0", report_row.call["CC TARGET STATUS"]
      assert_equal "4 / 1", report_row.call["General Training/Meeting"]
    end
    record.update!(data: record.data.merge("cluster_coordinator_name" => "Coordinator"))
    assert_equal "1 / 1", report_row.call["CC TARGET STATUS"]
  end

  test "all months adds recurring village targets and ignores duplicate activity rows" do
    july = target(@vrp, 350, "July")
    october = target(@vrp, 300, "October")
    duplicate = target(@vrp, 300, " October ")
    report = DemonstrationMethodReport.new(targets: [july, october, duplicate], month: "all")
    assert_equal 650, report.summary.sum { |row| row["OPG Target"].to_i }
    assert_equal 650, report.rows.sum { |row| row["General Training/Meeting Target"] }
    cc = CcDashboardReport.new(targets: [july, october, duplicate], vrps: [@vrp], month: "all")
    assert_equal 650, cc.jj_target
    assert_equal 650, cc.rows.first["Total OPG JJ Target"]
  end

  test "all months achievement is the sum of the twelve monthly achievements" do
    [nil, "", "All", "unknown"].each { |month| entry(@vrp, "FFS", month) }
    targets = @targets + TargetMapping.where(vrp_id: @vrp.id, month_name: "July").to_a + [target(@second, 0, "July")]
    totals = Date::MONTHNAMES.compact.sum do |month|
      DemonstrationMethodReport.new(targets: targets, month: month).achievement_totals.values.sum
    end
    all = DemonstrationMethodReport.new(targets: targets, month: "all")
    assert_equal 6, all.achievement_totals.values.sum
    assert_equal totals, all.achievement_totals.values.sum
    assert_equal 6, all.rows.sum { |row| row["OPG Achievement"] }
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
      month_name: month, main_activity_name: "Training", activity_name: "Demo", target_quantity: 0, opg_training_target: amount, week_wise_opg_target: amount)
  end

  def entry(vrp, method, month = " AUGUST ")
    ModuleRecord.create!(module_slug: "training-form", data: { created_by_id: vrp.id.to_s, month: month, training_method: method })
  end
end
