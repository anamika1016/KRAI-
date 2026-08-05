
require "test_helper"

class ModulesControllerSortingTest < ActiveSupport::TestCase
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
