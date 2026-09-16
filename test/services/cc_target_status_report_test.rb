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
end
