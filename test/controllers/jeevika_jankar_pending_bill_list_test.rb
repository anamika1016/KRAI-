require "test_helper"

class JeevikaJankarPendingBillListTest < ActionDispatch::IntegrationTest
  test "pending approval list shows a bill pending at the current approver and approve button works" do
    owner = User.create!(
      user_name: "qa_bill_owner_#{SecureRandom.hex(4)}",
      password: "secret",
      first_name: "Owner",
      last_name: "Test",
      stakeholder: "PAPL",
      role: "User",
      status: "Active"
    )
    approver = User.create!(
      user_name: "qa_sangam_#{SecureRandom.hex(4)}",
      password: "secret",
      first_name: "Sangam",
      last_name: "Kumari",
      stakeholder: "PAPL",
      role: "Manager ics",
      status: "Active"
    )
    vrp = Vrp.new(
      name: "QA Pending List VRP", aadhar_no: "123456789098", account_no: "1234567890",
      address: "Test", branch: "Test", date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      email: "qa-pending-list-vrp@example.com", experience_in_years: 1, father_husband_name: "Test",
      gender: :male, ifsc_code: "TEST0123456", mobile_no: "9876543988",
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

    get module_path("jeevika-jankar-pending-bill-list")
    assert_response :success
    assert_includes response.body, "QA Pending List VRP"
    assert_includes response.body, "Pending at Sangam Kumari (Manager ics)"
    assert_includes response.body, approve_bill_module_record_path("jeevika-jankar-bill-list", bill)
    assert_includes response.body, reject_bill_module_record_path("jeevika-jankar-bill-list", bill)

    patch approve_bill_module_record_path("jeevika-jankar-bill-list", bill), params: { remarks: "Looks good" }
    bill.reload
    assert_equal "Final Approved", bill.data["status"]

    get module_path("jeevika-jankar-pending-bill-list")
    assert_response :success
    refute_includes response.body, "QA Pending List VRP"
  end

  test "pending approval list shows every pending bill to an admin, not just their own turn" do
    owner = User.create!(
      user_name: "qa_bill_owner_#{SecureRandom.hex(4)}",
      password: "secret",
      first_name: "Owner",
      last_name: "Test",
      stakeholder: "PAPL",
      role: "User",
      status: "Active"
    )
    admin = User.create!(
      user_name: "qa_admin_#{SecureRandom.hex(4)}",
      password: "secret",
      first_name: "QA",
      last_name: "Admin",
      user_type: "admin",
      status: "Active"
    )
    vrp = Vrp.new(
      name: "QA Admin View VRP", aadhar_no: "123456789097", account_no: "1234567890",
      address: "Test", branch: "Test", date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      email: "qa-admin-view-vrp@example.com", experience_in_years: 1, father_husband_name: "Test",
      gender: :male, ifsc_code: "TEST0123456", mobile_no: "9876543977",
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
        "approver_approved_by" => "Someone Else (Manager ics)",
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
    assert_equal "Pending at Someone Else (Manager ics)", bill.reload.data["status"]
    delete logout_path

    # Admin is not "Someone Else", so the personal current-approver match never
    # fires for them -- they should still see the bill in the full queue, just
    # without a working Approve/Reject (that stays reserved for the real approver).
    post login_path, params: { login: admin.user_name, password: "secret" }
    follow_redirect!

    get module_path("jeevika-jankar-pending-bill-list")
    assert_response :success
    assert_includes response.body, "QA Admin View VRP"
    assert_includes response.body, "Pending at Someone Else (Manager ics)"
    refute_includes response.body, approve_bill_module_record_path("jeevika-jankar-bill-list", bill)
  end
end
