require "test_helper"

# Reported from the Farmer Training Participation Status -> View List download:
# the Training Dates column arrived as one cell holding every date a farmer
# attended -- "2026-07-05, 2026-08-14, 2026-09-21, 2026-10-14" -- which cannot
# be sorted, filtered or pivoted in Excel. Each date now gets its own row with
# the farmer's full detail repeated.
#
# Only this download changes. The View List table on the page still renders
# @training_participation_rows exactly as before.
class TrainingParticipationExportDatesTest < ActiveSupport::TestCase
  setup do
    @controller = ModulesController.new
    @headers = @controller.send(:training_participation_export_headers)
    @date_index = @headers.index("Training Date")
    @row = {
      farmer_id: 7, farmer_name: "Ramesh", father_name: "Suresh", mobile_no: "9876543210",
      tracenet_no: "958389030476", ics: "KOPRAWADI AMBADA FARMERS PRODUCER COMPANY LIMITED",
      village: "Banabakoda", fcoc: "Sausar", cluster_incharge: "Mahendra Dufare",
      jeevika_jankar_name: "Prachi Kale", registered_by: "Prachi Kale",
      months: "All Months", main_activities: "Farmers' Training",
      sub_activities: "1. Organic Introduction", attendance_count: 4,
      status_label: "1+ Trainings",
      training_dates: "2026-07-05, 2026-08-14, 2026-09-21, 2026-10-14",
      last_training_date: "2026-10-14",
      training_register_urls: ["/uploads/r1.pdf"], training_photo_urls: ["/uploads/p1.jpg"]
    }
  end

  test "the sheet has a singular Training Date column" do
    assert_includes @headers, "Training Date"
    refute_includes @headers, "Training Dates"
    assert_equal "Last Training Date", @headers[@date_index + 1],
      "the surrounding columns keep their order"
  end

  test "a farmer with four training dates becomes four rows, one per date" do
    rows = export([@row])

    assert_equal 4, rows.size
    assert_equal ["2026-07-05", "2026-08-14", "2026-09-21", "2026-10-14"],
      rows.map { |row| row[@date_index] }
    assert rows.none? { |row| row[@date_index].to_s.include?(",") },
      "no cell may hold more than one date"
  end

  test "every other column is repeated so each row carries the full detail" do
    rows = export([@row])
    other_columns = (0...@headers.size).reject { |index| index == @date_index }

    other_columns.each do |index|
      values = rows.map { |row| row[index] }.uniq
      assert_equal 1, values.size, "#{@headers[index]} should be the same on every row"
    end
    assert_equal "958389030476", rows.first[@headers.index("TraceNet No")]
    assert_equal 4, rows.first[@headers.index("Training Count")],
      "Training Count keeps reporting the farmer's total"
    assert_equal "2026-10-14", rows.first[@headers.index("Last Training Date")]
  end

  test "a single date still produces exactly one row" do
    rows = export([@row.merge(training_dates: "2026-07-05", attendance_count: 1)])

    assert_equal 1, rows.size
    assert_equal "2026-07-05", rows.first[@date_index]
  end

  test "a farmer with no recorded date is still exported" do
    ["-", "", nil].each do |value|
      rows = export([@row.merge(training_dates: value)])
      assert_equal 1, rows.size, "#{value.inspect} must not drop the farmer from the sheet"
      assert_equal "Ramesh", rows.first[@headers.index("Farmer")]
    end
  end

  test "the row count is the total number of training dates" do
    second = @row.merge(farmer_id: 8, farmer_name: "Sita",
      training_dates: "2026-05-02, 2026-06-09", attendance_count: 2)

    assert_equal 6, export([@row, second]).size
  end

  test "an empty list stays empty" do
    assert_empty export([])
  end

  private

  def export(rows)
    @controller.send(:training_participation_export_rows, rows)
  end
end
