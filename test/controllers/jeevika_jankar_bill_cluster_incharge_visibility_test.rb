require "test_helper"

class JeevikaJankarBillClusterInchargeVisibilityTest < ActionDispatch::IntegrationTest
  test "a cluster incharge can see, filter, and resend a bill their JJ had submitted by someone else" do
    admin = User.create!(
      user_name: "qa_admin_submitter_#{SecureRandom.hex(4)}",
      password: "secret",
      first_name: "Admin",
      last_name: "Submitter",
      user_type: "admin",
      status: "Active"
    )
    cc = User.create!(
      user_name: "qa_cc_incharge_#{SecureRandom.hex(4)}",
      password: "secret",
      first_name: "Ravichand",
      last_name: "Bhalavi",
      stakeholder: "PAPL",
      role: "Cluster Incharge",
      status: "Active"
    )
    vrp = Vrp.new(
      name: "QA CC Visibility VRP", aadhar_no: "123456789093", account_no: "1234567890",
      address: "Test", branch: "Test", date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      email: "qa-cc-visibility@example.com", experience_in_years: 1, father_husband_name: "Test",
      gender: :male, ifsc_code: "TEST0123456", mobile_no: "9876543933",
      office_detail_id: 0, to_office_detail_id: 0, status: 55, created_by_id: admin.id,
      cluster_incharge: "Ravichand bhalavi"
    )
    vrp.save!(validate: false)

    # The admin (not the CC) submitted and it was rejected -- the real-world
    # shape of the bug report: the JJ's own Cluster Incharge could not find
    # this bill anywhere in their Bill List to edit and resend it.
    bill = ModuleRecord.create!(
      module_slug: "jeevika-jankar-bill-process",
      data: {
        "select_vrp" => vrp.id.to_s,
        "select_vrp_name" => vrp.name,
        "financial_year" => "2026-2027",
        "bill_month" => "September",
        "created_by_id" => admin.id.to_s,
        "created_by_username" => admin.user_name,
        "created_by_name" => admin.full_name,
        "status" => "Rejected"
      }
    )

    post login_path, params: { login: cc.user_name, password: "secret" }
    follow_redirect!

    get module_path("jeevika-jankar-bill-list", bill_month: "September", bill_status: "rejected")
    assert_response :success
    assert_includes response.body, "QA CC Visibility VRP"

    get module_path("jeevika-jankar-bill-list", view_id: bill.id)
    assert_response :success
    refute_includes response.body, "You are not allowed to view this bill."
  end
end
