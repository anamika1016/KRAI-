require "minitest/autorun"
require "ostruct"
require_relative "../app/services/cc_dashboard_report"

class DemonstrationMethodReport; end unless defined?(DemonstrationMethodReport)

class CcDashboardReportUnitTest < Minitest::Test
  # Minitest 6 no longer ships minitest/mock, so Object#stub is gone. Swap the
  # class method for the block's duration and put the original back afterwards.
  def with_stubbed_new(klass, replacement)
    singleton = klass.singleton_class
    singleton.alias_method(:__original_new, :new)
    singleton.define_method(:new) { |*args, **kwargs, &blk| replacement.call(*args, **kwargs, &blk) }
    yield
  ensure
    singleton.alias_method(:new, :__original_new)
    singleton.remove_method(:__original_new)
  end

  def test_totals_use_only_visible_jjs_and_deduplicate_opg_by_month_and_village
    targets = [[1, "August", "v1", 4], [1, "August", "v1", 4], [1, "September", "v1", 3]].map do |id, month, village, opg|
      OpenStruct.new(vrp_id: id, month_name: month, village_id: village, opg_training_target: opg)
    end
    details = OpenStruct.new(summary: [{ "OPG Target" => 7 }], rows: [
      { "vrp_id" => 1, "CC Target" => 5, "CC Achievement" => 2, "OPG Target" => 4, "OPG Achievement" => 3,
        "General Training/Meeting Target" => 4, "General Training/Meeting Achievement" => 3 },
      { "vrp_id" => 99, "CC Target" => 100, "CC Achievement" => 100 }
    ])
    calls = []
    factory = lambda do |targets:, month:|
      calls << month
      assert targets.all? { |target| target.month_name.downcase == month } if month
      details
    end
    with_stubbed_new(DemonstrationMethodReport, factory) do
      report = CcDashboardReport.new(targets: targets, vrps: [OpenStruct.new(id: 1, name: "Own JJ"), OpenStruct.new(id: 2, name: "Empty JJ")], month: nil)
      assert_equal 10, report.target
      assert_equal 4, report.achievement
      assert_equal 7, report.jj_target
      assert_equal 3, report.jj_achievement
      assert_equal ["CC Target", "CC Achievement", "Total OPG JJ Target", "Total OPG JJ Achievement"], CcDashboardReport::HEADERS[1, 4]
      refute_includes CcDashboardReport::HEADERS, "Total OPG"
      assert_equal ["august", "september", nil], calls
      assert_equal ["Own JJ", "Empty JJ"], report.rows.map { |row| row["JJ Name"] }
      assert_equal 7, report.rows.first["Total OPG"]
      assert_equal 7, report.rows.first["Total OPG JJ Target"]
      assert_equal "7 / 3", report.rows.first["OPG Training"]
      assert_equal "8 / 3", report.rows.first["General Training/Meeting"]
      assert_equal 0, report.rows.last["CC Target"]
    end
  end
end
