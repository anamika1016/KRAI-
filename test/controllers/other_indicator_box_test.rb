require "test_helper"

# The "Main Major Work Indicator - Other" box reads the saved Other Target
# entries: target and achievement summed from those entries, broken down per
# FCO in the hover popup.
class OtherIndicatorBoxTest < ActiveSupport::TestCase
  setup do
    entry("Sausar",   "Internal Inspection", "Documentation", 36, 30)
    entry("Turekela", "Seed Packet Distribution", "Non GMO Seed", 100, 40)
    # A different month must stay out of a September box.
    entry("Sausar", "Internal Inspection", "Documentation", 500, 500, month: "August")
  end

  test "the box totals the saved September entries" do
    t = totals(month: "September")

    assert_equal 136, t[:mapped_farmer], "target should be 36 + 100"
    assert_equal 70,  t[:achievement_farmer], "achievement should be 30 + 40"
    assert_equal 66,  t[:pending_farmer]
    assert_equal 2,   t[:main_major_work_indicator]
  end

  test "achieved percent is achievement over target" do
    assert_equal (70 * 100.0 / 136).round(2), totals(month: "September")[:achieved]
  end

  test "the popup lists every project FCO, zero included" do
    assert_equal ["Sausar = 30/36", "Turekela = 40/100", "Pavijetpur = 0/0"],
                 totals(month: "September")[:main_major_work_indicator_popups],
                 "All FCO must list 1004, 1006 and 1095 even when one has no entries"
  end

  test "selecting one FCO shows only that FCO in the popup" do
    assert_equal ["Sausar = 30/36"],
                 totals(month: "September", fcoc: "FCO-C Sausar")[:main_major_work_indicator_popups]
  end

  test "the month filter is honoured" do
    assert_equal 500, totals(month: "August")[:mapped_farmer]
  end

  test "the FCO filter narrows to one FCO" do
    t = totals(month: "September", fcoc: "FCO-C Sausar")

    assert_equal 36, t[:mapped_farmer], "FCO-C prefix should still match a plain 'Sausar' entry"
    assert_equal 30, t[:achievement_farmer]
  end

  test "all three project FCOs are included when none is selected" do
    entry("Pavijetpur", "Compost", "Pit Making", 20, 5)
    t = totals(month: "September")

    assert_equal 156, t[:mapped_farmer], "Pavijetpur (1095) must be counted too"
    assert_equal 75,  t[:achievement_farmer]
  end

  test "an FCO outside the project is excluded" do
    entry("Elsewhere", "Compost", "Pit Making", 999, 999)
    t = totals(month: "September")

    assert_equal 136, t[:mapped_farmer], "only Sausar, Turekela and Pavijetpur belong here"
    assert_equal 70,  t[:achievement_farmer]
  end

  test "an FCO-C prefixed entry is counted without a filter" do
    entry("FCO-C Pavijetpur", "Compost", "Pit Making", 20, 5)
    t = totals(month: "September")

    assert_equal 156, t[:mapped_farmer]
  end

  test "the list returns one row per saved entry" do
    rows = controller(month: "September").send(:dashboard_other_target_entry_rows)

    assert_equal 2, rows.size
    assert_equal %w[jeevika_jankar_name fco_name month main_activity sub_activity target achievement status target_mapping_id].sort,
                 rows.first.keys.sort
  end

  private

  def entry(fco, main, sub, target, achievement, month: "September")
    ModuleRecord.create!(module_slug: "other-target", data: {
      "fcoc_name" => fco, "month" => month, "main_activity" => main, "sub_activity" => sub,
      "target" => target.to_s, "achievement" => achievement.to_s
    })
  end

  def controller(month:, fcoc: nil)
    c = ModulesController.new
    c.request = ActionDispatch::TestRequest.create
    c.params = ActionController::Parameters.new({ month: month, fcoc: fcoc }.compact)
    c.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
    c.instance_variable_set(:@dashboard_month_filter_value, month)
    c.instance_variable_set(:@dashboard_fcoc_filter_value, fcoc)
    c
  end

  def totals(month:, fcoc: nil)
    controller(month: month, fcoc: fcoc).send(:dashboard_other_activity_totals, nil)
  end
end
