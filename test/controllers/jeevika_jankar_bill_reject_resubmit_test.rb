require "test_helper"

class JeevikaJankarBillRejectResubmitTest < ActionDispatch::IntegrationTest
  test "a rejected bill can be resent for approval and approved again by the same approver" do
    owner = User.create!(
      user_name: "qa_resubmit_owner_#{SecureRandom.hex(4)}",
      password: "secret",
      first_name: "Owner",
      last_name: "Test",
      stakeholder: "PAPL",
      role: "User",
      status: "Active"
    )
    approver = User.create!(
      user_name: "qa_resubmit_approver_#{SecureRandom.hex(4)}",
      password: "secret",
      first_name: "Sangam",
      last_name: "Kumari",
      stakeholder: "PAPL",
      role: "Manager ics",
      status: "Active"
    )
    vrp = Vrp.new(
      name: "QA Resubmit VRP", aadhar_no: "123456789095", account_no: "1234567890",
      address: "Test", branch: "Test", date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      email: "qa-resubmit-vrp@example.com", experience_in_years: 1, father_husband_name: "Test",
      gender: :male, ifsc_code: "TEST0123456", mobile_no: "9876543955",
      office_detail_id: 0, to_office_detail_id: 0, status: 55, created_by_id: owner.id
    )
    vrp.save!(validate: false)

    ModuleRecord.create!(
      module_slug: "approval-master",
      data: {
        "module_name" => "Jeevika Jankar Bill",
        "stakeholder_name" => "PAPL",
        "user_name" => owner.user_name,
        "approval_level" => "First Appovel",
        "approver_approved_by" => "Sangam Kumari (Manager ics)",
        "status" => "Active"
      }
    )
    bill = ModuleRecord.create!(
      module_slug: "jeevika-jankar-bill-process",
      data: {
        "select_vrp" => vrp.id.to_s,
        "select_vrp_name" => vrp.name,
        "financial_year" => "2026-2027",
        "bill_month" => "June",
        "created_by_id" => owner.id.to_s,
        "created_by_username" => owner.user_name,
        "created_by_name" => owner.full_name,
        "status" => "Submitted (Not sent for approval)"
      }
    )

    post login_path, params: { login: owner.user_name, password: "secret" }
    follow_redirect!
    patch send_for_approval_module_record_path("jeevika-jankar-bill-list", bill)
    assert_equal "Pending at Sangam Kumari (Manager ics)", bill.reload.data["status"]
    delete logout_path

    post login_path, params: { login: approver.user_name, password: "secret" }
    follow_redirect!
    patch reject_bill_module_record_path("jeevika-jankar-bill-list", bill), params: { remarks: "Amount looks wrong" }
    assert_equal "Rejected", bill.reload.data["status"]
    delete logout_path

    # Owner edits the bill and sends it for approval again.
    post login_path, params: { login: owner.user_name, password: "secret" }
    follow_redirect!
    bill.update!(data: bill.data.merge("remarks" => "fixed the amount"))
    patch send_for_approval_module_record_path("jeevika-jankar-bill-list", bill)
    assert_equal "Pending at Sangam Kumari (Manager ics)", bill.reload.data["status"]

    # The Approval Progress card for step 1 must reset to pending/current, not
    # keep showing the old rejection (cross icon + stale "Rejected at ..." line)
    # from before this fresh resubmission.
    get module_path("jeevika-jankar-bill-list", view_id: bill.id)
    assert_response :success
    refute_includes response.body, "approval-progress-card rejected"
    assert_includes response.body, "approval-progress-card current"
    delete logout_path

    # The same approver must be able to act on this fresh submission -- the
    # bug was that the old "Rejected" history entry made the approval step
    # look already closed, so the approve button/action silently refused to
    # work even though the bill correctly showed "Pending at <approver>".
    post login_path, params: { login: approver.user_name, password: "secret" }
    follow_redirect!

    get module_path("jeevika-jankar-pending-bill-list")
    assert_response :success
    assert_includes response.body, "QA Resubmit VRP"
    assert_includes response.body, approve_bill_module_record_path("jeevika-jankar-bill-list", bill)

    patch approve_bill_module_record_path("jeevika-jankar-bill-list", bill), params: { remarks: "Looks good now" }
    assert_equal "Final Approved", bill.reload.data["status"]
  end
end
