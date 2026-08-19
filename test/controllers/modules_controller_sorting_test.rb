
require "test_helper"

class ModulesControllerSortingTest < ActiveSupport::TestCase
  test "training population matches attendance by distinct farmer identity instead of AFL row id" do
    controller = ModulesController.new
    farmer = Struct.new(:farmer_name, :tracenet_no).new("Test Farmer", "TN-100")
    record = Struct.new(:id, :data).new(1,
      "selected_farmer_ids" => ["22"],
      "selected_farmer_names" => ["Test Farmer"],
      "ics_block" => "ICS One",
      "gram_name" => "Village One"
    )

    controller.define_singleton_method(:training_afl_farmer_rows_for_participation) do |**|
      [{ farmer_key: "tracenet:tn-100", farmer_id: "11", source_farmer_ids: ["11"], assigned_activity_count: 2 }]
    end
    controller.define_singleton_method(:training_farmers_by_id) { |_| { "22" => farmer } }
    controller.define_singleton_method(:training_participation_month_open?) { |_| false }

    row = controller.send(
      :training_participation_population_rows,
      month_name: "July",
      fcoc_name: "FCO-C Sausar",
      records: [record]
    ).first

    assert_equal 1, row[:attendance_count]
    assert_equal "yellow", row[:status]
  end

  test "training FCOC filters match full label and short AFL office names" do
    controller = ModulesController.new

    assert controller.send(:training_fcoc_text_matches?, "Sausar", "FCO-C Sausar")
    assert controller.send(:training_fcoc_text_matches?, "FCO-C Turekela", "Turekela")
    assert_not controller.send(:training_fcoc_text_matches?, "Sausar", "FCO-C Turekela")

    assert_equal ["fco-c sausar", "sausar"], controller.send(:training_fcoc_filter_values, "FCO-C Sausar")
  end

  test "Jeevika Jankar bill list puts submitted and pending bills before approved bills" do
    controller = ModulesController.new
    current_month = Date.current.beginning_of_month
    previous_month = current_month.prev_month

    pending_previous = bill_record(1, "Pending at Manager", previous_month)
    approved_current = bill_record(2, "Final Approved", current_month)
    pending_current = bill_record(3, "Pending at Manager", current_month)
    approved_previous = bill_record(4, "Final Approved", previous_month)
    submitted_current = bill_record(5, "Submitted (Not sent for approval)", current_month)

    sorted = [approved_previous, pending_previous, approved_current, pending_current, submitted_current]
      .sort_by { |record| controller.send(:jeevika_bill_list_sort_value, record) }

    assert_equal [submitted_current, pending_current, pending_previous, approved_current, approved_previous], sorted
  end

  private

  def bill_record(id, status, month)
    financial_year_start = month.month >= 4 ? month.year : month.year - 1
    ModuleRecord.new(
      id: id,
      module_slug: "jeevika-jankar-bill-process",
      data: {
        "status" => status,
        "bill_month" => month.strftime("%B"),
        "financial_year" => "#{financial_year_start}-#{financial_year_start + 1}"
      }
    )
  end
end
