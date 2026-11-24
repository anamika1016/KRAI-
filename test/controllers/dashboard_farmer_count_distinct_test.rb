require "test_helper"

# Reported: a CC dashboard showed Mapped Farmer 1240 against Total Farmer Count
# 1154 -- more farmers mapped than exist. One cause is here: Total Farmer Count
# ran COUNT(tracenet_no), not COUNT(DISTINCT ...), while Mapped Farmer always
# counted distinct farmers. The AFL import repeats a farmer row (the same
# Tracenet, name, FCO, ICS and village saved up to 8 times), so the same person
# was counted several times.
class DashboardFarmerCountDistinctTest < ActiveSupport::TestCase
  setup do
    @controller = ModulesController.new
    @controller.request = ActionDispatch::TestRequest.create
    admin = User.create!(first_name: "Count", last_name: "Distinct",
      user_name: "count_distinct_#{SecureRandom.hex(3)}",
      email: "count-distinct-#{SecureRandom.hex(3)}@example.test",
      mobile_no: "9876500997", password: "secret", user_type: "admin", status: "Active")
    @controller.instance_variable_set(:@current_app_user,
      ApplicationController.new.send(:app_user_session_payload, admin))
  end

  test "one farmer saved several times is counted once" do
    3.times do
      Afl.create!(farmer_name: "Repeated Farmer", tracenet_no: "RTC-DUP-1",
        fco_id: "1004", fco: "Sausar", ics_id: "ics-d", village_id: "v-d")
    end
    Afl.create!(farmer_name: "Other Farmer", tracenet_no: "RTC-DUP-2",
      fco_id: "1004", fco: "Sausar", ics_id: "ics-d", village_id: "v-d")

    assert_equal 2, count_for("1004"), "three rows of one Tracenet are one farmer"
  end

  # Deliberately unchanged: the card has always identified a farmer by their
  # Tracenet number, so a row without one is not counted. Only the repeats are
  # collapsed.
  test "rows without a Tracenet are still left out, as before" do
    Afl.create!(farmer_name: "No Tracenet", tracenet_no: nil,
      fco_id: "1006", fco: "Turekela", ics_id: "ics-b", village_id: "v-b")
    Afl.create!(farmer_name: "Blank Tracenet", tracenet_no: "  ",
      fco_id: "1006", fco: "Turekela", ics_id: "ics-b", village_id: "v-b")
    Afl.create!(farmer_name: "Real", tracenet_no: "RTC-B-1",
      fco_id: "1006", fco: "Turekela", ics_id: "ics-b", village_id: "v-b")

    assert_equal 1, count_for("1006")
  end

  test "the same Tracenet in different letter case is one farmer" do
    Afl.create!(farmer_name: "Upper", tracenet_no: "RTC-CASE-1", fco_id: "1009")
    Afl.create!(farmer_name: "Lower", tracenet_no: "rtc-case-1", fco_id: "1009")

    assert_equal 1, count_for("1009")
  end

  # Direct to HO has its own rule: it must keep a row that has no Tracenet at
  # all. The code comment said those rows carry no Tracenet, so it counted rows
  # -- but every Direct to HO row here does carry one and 502 of them repeat,
  # so the card read 2285 where 1783 farmers exist.
  test "Direct to HO collapses repeats but never drops a row without a Tracenet" do
    3.times do
      Afl.create!(farmer_name: "DtHO Repeated", tracenet_no: "RTC-HO-1", fco_id: "1095")
    end
    2.times do |index|
      Afl.create!(farmer_name: "DtHO No Tracenet #{index}", tracenet_no: nil, fco_id: "1095")
    end

    scope = Afl.where(fco_id: "1095")
    assert_equal 3, scope.distinct.count(@controller.send(:dashboard_farmer_row_identity_sql)),
      "one repeated farmer plus two different farmers without a Tracenet"
    assert_equal 5, scope.count(:id), "the old row count saw five"
  end

  private

  # Counts distinct farmers in one FCO through the same expression the card uses.
  def count_for(fco_id)
    Afl.where(fco_id: fco_id).distinct.count(@controller.send(:dashboard_farmer_identity_sql))
  end
end
