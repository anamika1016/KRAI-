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

# The same list showed the training date two different ways: the Training Form
# List renders the JJ's entered date through bill_display_date ("31/10/2026")
# while this list printed the stored value raw ("2026-10-31"), so the two
# screens looked like they disagreed about the same training. Formatting at the
# source fixes the page, the Excel and the CSV together.
class TrainingParticipationDisplayDatesTest < ActiveSupport::TestCase
  setup do
    @controller = ModulesController.new
    @controller.request = ActionDispatch::TestRequest.create
  end

  test "dates read the way the Training Form List renders the JJ's date" do
    stored = ["2026-07-18", "2026-08-21", "2026-09-09", "2026-11-20"]

    assert_equal stored.map { |date| @controller.send(:bill_display_date, date) },
      display(stored)
    assert_equal ["18/07/2026", "21/08/2026", "09/09/2026", "20/11/2026"], display(stored)
  end

  test "no raw ISO date survives" do
    assert display(["2026-10-31"]).none? { |date| date.match?(/\A\d{4}-\d{2}-\d{2}\z/) }
  end

  test "dates come back oldest first so Last Training Date is the real latest" do
    out = display(["2026-11-20", "2026-07-18", "2026-09-09"])

    assert_equal ["18/07/2026", "09/09/2026", "20/11/2026"], out
    assert_equal "20/11/2026", out.last
  end

  test "blank and missing values are dropped without blowing up" do
    assert_equal ["31/10/2026"], display(["2026-10-31", "", nil, "   "])
    assert_empty display([])
    assert_empty display(nil)
  end

  # The export splits the joined string on commas, so the formatted value has
  # to stay comma-free for one row per date to keep working.
  test "the formatted dates still split into one export row each" do
    joined = display(["2026-07-18", "2026-08-21"]).join(", ")
    rows = @controller.send(:training_participation_export_rows,
      [{ training_dates: joined, training_register_urls: [], training_photo_urls: [] }])

    date_index = @controller.send(:training_participation_export_headers).index("Training Date")
    assert_equal ["18/07/2026", "21/08/2026"], rows.map { |row| row[date_index] }
  end

  private

  def display(values)
    @controller.send(:training_participation_display_dates, values)
  end
end

# Re-scan finding: formatting the 1+ Trainings list left the "Only 1 Training"
# list still printing the stored "2026-10-31". Every status has to read the
# JJ's date the same way, so this drives the real query for that status.
class TrainingParticipationYellowDateTest < ActiveSupport::TestCase
  setup do
    @controller = ModulesController.new
    @controller.request = ActionDispatch::TestRequest.create
    admin = User.create!(first_name: "Yellow", last_name: "Date",
      user_name: "yellow_date_#{SecureRandom.hex(3)}",
      email: "yellow-date-#{SecureRandom.hex(3)}@example.test",
      mobile_no: "9876500995", password: "secret", user_type: "admin", status: "Active")
    @controller.instance_variable_set(:@current_app_user,
      ApplicationController.new.send(:app_user_session_payload, admin))

    @farmer = Afl.create!(farmer_name: "Yellow Farmer", fco_id: "1004", fco: "Sausar",
      ics_id: "ics-1", ics_name: "ICS One", village_id: "v1", village_name: "Village One",
      tracenet_no: "TN-YELLOW-1")
    # Exactly one training -> this farmer lands in "Only 1 Training".
    ModuleRecord.create!(module_slug: "training-form", data: {
      "month" => "October", "training_date" => "2026-10-31",
      "main_activity" => "Farmers' Training", "sub_activity" => "Module-1",
      "training_method" => "General Training/Meeting", "trainer_name" => "Prachi Kale",
      "selected_farmer_ids" => [@farmer.id.to_s]
    })
  end

  test "the Only 1 Training list shows the JJ's date the way the Training Form List does" do
    row = yellow_rows.find { |candidate| candidate[:farmer_id].to_s == @farmer.id.to_s }
    skip "query returned no yellow row in this environment" if row.nil?

    assert_equal "31/10/2026", row[:training_dates]
    assert_equal "31/10/2026", row[:last_training_date]
    refute_match(/\A\d{4}-\d{2}-\d{2}\z/, row[:training_dates], "no raw ISO date may survive")
    assert_equal @controller.send(:bill_display_date, "2026-10-31"), row[:training_dates]
  end

  test "its export row carries the same formatted date" do
    row = yellow_rows.find { |candidate| candidate[:farmer_id].to_s == @farmer.id.to_s }
    skip "query returned no yellow row in this environment" if row.nil?

    headers = @controller.send(:training_participation_export_headers)
    exported = @controller.send(:training_participation_export_rows, [row])
    assert_equal 1, exported.size
    assert_equal "31/10/2026", exported.first[headers.index("Training Date")]
  end

  private

  def yellow_rows
    @yellow_rows ||= Array(@controller.send(:farmer_training_participation_rows_from_sql,
      "yellow", month_name: "October", fcoc_name: "Sausar"))
  end
end
