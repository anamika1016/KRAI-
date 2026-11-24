require "test_helper"

# Reported: "CC login me Main Major Work Indicator - Other me data blank aa raha
# hai" for November. Root cause -- dashboard_vrps (via scoped_jeevika_vrp_visible?)
# decides which JJs a CC can see for every dashboard total, including this box's
# target_mapping scope. module_cluster_visible_vrps (used by the same box's own
# entry-rows query, and by the Jeevika Jankar list) already treated a
# jeevika-jankar-transfer record as a visibility grant; scoped_jeevika_vrp_visible?
# did not. A JJ reaching a CC only through a transfer (not a direct
# cluster_incharge name match) was visible everywhere else on the dashboard but
# silently dropped out of this one box's total.
class OtherTargetCcTransferredJjVisibilityTest < ActiveSupport::TestCase
  setup do
    # dashboard_other_mapping_progress_rows only counts a target whose main
    # activity is classified "Other" via add-activity-group; an unclassified
    # activity defaults to "Training" and is excluded regardless of visibility.
    ModuleRecord.create!(module_slug: "add-activity-group", data: {
      "main_activity_name" => "framer whatsup", "main_activity_type" => "Other", "status" => "Active"
    })
  end

  def create_vrp(cluster_incharge:)
    vrp = Vrp.new(name: "Transferred JJ #{SecureRandom.hex(3)}", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "98765#{rand(10000..99999)}", email: "transferred-jj-#{SecureRandom.hex(4)}@example.test",
      fcoc: "Sausar", cluster_incharge: cluster_incharge, is_active: true, status: 55,
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    vrp.save!(validate: false)
    vrp
  end

  def transfer_to(cc_name, vrp)
    ModuleRecord.create!(module_slug: "jeevika-jankar-transfer", data: {
      "sidebar_menu" => "", "user_name" => cc_name, "status" => "Active",
      "jeevika_jankar_names" => ["#{vrp.name} - #{vrp.mobile_no} - #{vrp.id}"]
    })
  end

  def other_totals_as(cc_name, month)
    controller = ModulesController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.params = ActionController::Parameters.new(month: month)
    controller.define_singleton_method(:current_app_user) { { "user_type" => "User", "role" => "Cluster Incharge", "name" => cc_name, "username" => cc_name } }
    controller.instance_variable_set(:@dashboard_month_filter_value, month)
    controller.send(:dashboard_other_activity_totals)
  end

  test "a JJ reaching a CC only through a transfer still counts in the Other box" do
    cc_name = "Transfer Receiver #{SecureRandom.hex(3)}"
    # Not a direct cluster_incharge match -- the transfer is the only reason
    # this CC should see this JJ.
    vrp = create_vrp(cluster_incharge: "Someone Else Entirely")
    TargetMapping.new(vrp: vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "transfer-ics",
      ics_name: "Transfer ICS", village_id: "transfer-village", month_name: "November",
      main_activity_name: "framer whatsup", activity_name: "farmenr whatsup data", target_quantity: 5)
      .save!(validate: false)
    transfer_to(cc_name, vrp)

    totals = other_totals_as(cc_name, "November")
    assert_equal 1, totals[:main_major_work_indicator], totals.inspect
    assert_equal 5, totals[:mapped_farmer], "the transferred JJ's target must count in the box total"
  end

  test "a JJ not transferred and not directly mapped stays out of the Other box" do
    cc_name = "Unrelated CC #{SecureRandom.hex(3)}"
    vrp = create_vrp(cluster_incharge: "Someone Else Entirely")
    TargetMapping.new(vrp: vrp, fco_id: "1004", fco_name: "Sausar", ics_id: "unrelated-ics",
      ics_name: "Unrelated ICS", village_id: "unrelated-village", month_name: "November",
      main_activity_name: "framer whatsup", activity_name: "farmenr whatsup data", target_quantity: 5)
      .save!(validate: false)
    # No transfer record for cc_name -- this JJ must stay invisible to them.

    totals = other_totals_as(cc_name, "November")
    assert_equal 0, totals[:mapped_farmer], "an untransferred, unmapped JJ must not leak into another CC's total"
  end
end
