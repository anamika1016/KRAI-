require "test_helper"

class CcTargetStatusReportTest < ActiveSupport::TestCase
  test "calculates cc target status correctly with Red, Yellow, Green status" do
    report = CcTargetStatusReport.new(calculator: nil, month: "August", fco: "1004")
    assert_respond_to report, :summary
    assert_respond_to report, :rows
    assert_respond_to report, :caption

    summary = report.summary
    assert_kind_of Array, summary
    statuses = summary.map { |r| r["status"] }
    assert_includes statuses, "Red"
    assert_includes statuses, "Yellow"
    assert_includes statuses, "Green"
  end
  test "includes actual FCO targets instead of assigning other FCOs to Sausar" do
    report = CcTargetStatusReport.new(calculator: nil, month: "September")
    report.define_singleton_method(:fetch_cc_targets) { { ["1009", "Coordinator"] => 3 } }
    report.define_singleton_method(:fetch_cc_achievements) { { ["1009", "Coordinator"] => 1 } }
    report.define_singleton_method(:fetch_cc_jj_names) { {} }
    assert_equal 3, report.rows.first.fetch("target")
    assert_equal "1009", report.rows.first.fetch("fco_id")
    assert_equal 3, report.summary.sum { |row| row.fetch("total_target") }
    assert_equal 1, report.summary.sum { |row| row.fetch("total_achievement") }
    assert_equal "1009", report.send(:normalize_fco_id, "1009", "Bhabra")
    assert_equal "1009", report.send(:normalize_fco_id, "1009", "Bhabra", "Sausar")
    assert_equal "1004", report.send(:normalize_fco_id, nil, nil, "Sausar")
    assert_equal "", report.send(:normalize_fco_id, nil, nil, nil)
  end

end
