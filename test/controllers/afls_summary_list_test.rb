require "test_helper"

class AflsSummaryListTest < ActiveSupport::TestCase
  test "ICS and village drill-downs use the same unique IDs as dashboard cards" do
    first = Afl.create!(fco_id: "1095", fco: "Direct to HO", fpo_id: "24", fpo_name: "First FPO",
      ics_id: "125", ics_name: "One ICS", village_id: "V-1", village_name: "One Village",
      farmer_name: "First", tracenet_no: "first")
    second = Afl.create!(fco_id: "1095", fco: "Direct to HO", fpo_id: "100", fpo_name: "Second FPO",
      ics_id: "125", ics_name: "One ICS renamed", village_id: "V-1", village_name: "One Village renamed",
      farmer_name: "Second", tracenet_no: "second")
    third = Afl.create!(fco_id: "1095", fco: "Direct to HO", fpo_id: "101", fpo_name: "Third FPO",
      ics_id: "126", ics_name: "Second ICS", village_id: "V-2", village_name: "Second Village",
      farmer_name: "Third", tracenet_no: "third")

    controller = AflsController.new
    controller.instance_variable_set(:@summary_mode, "ics")
    scope = Afl.where(id: [first.id, second.id, third.id])
    ics_rows = controller.send(:grouped_afl_scope, scope)

    assert_equal 2, ics_rows.size
    assert_equal "1094", ics_rows.first[:fco_id]
    assert_equal "Direct to HO", ics_rows.first[:fco]

    controller.instance_variable_set(:@summary_mode, "village")
    village_rows = controller.send(:grouped_afl_scope, scope)

    assert_equal 2, village_rows.size
  end
end
