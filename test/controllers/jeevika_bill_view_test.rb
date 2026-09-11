require "test_helper"

class JeevikaBillViewTest < ActionDispatch::IntegrationTest
  test "bill detail view renders even when farmer_details is a Hash, not an Array" do
    user = User.create!(first_name: "Bill", last_name: "Admin", user_name: "bill_view_admin",
      email: "bill-view-admin@example.test", mobile_no: "9876500099", password: "secret",
      user_type: "admin", status: "Active")
    post login_path, params: { login: user.user_name, password: "secret" }

    # farmer_details as a Hash (keyed) instead of an Array reproduces the 500:
    # Array(hash) yields [k, v] pairs and pair.merge raised NoMethodError.
    record = ModuleRecord.create!(module_slug: "jeevika-jankar-bill-process", data: {
      "select_vrp" => "1", "select_vrp_name" => "Test JJ",
      "bill_month" => "August", "financial_year" => "2026-2027",
      "created_by_name" => "Preparer",
      "bill_items" => [
        { "village" => "Ghogari", "main_activity" => "Farmers' Training", "activity" => "Module-4",
          "target_quantity" => 10, "achievement_count" => 5, "pending_count" => 5,
          "rate" => "100", "amount" => "500",
          "farmer_details" => { "0" => { "name" => "Farmer One", "mobile_no" => "9990001111" } } }
      ]
    })

    ModuleRecord.create!(module_slug: "approval-master", data: {
      "module_name" => "Jeevika Jankar Bill", "approval_level" => "First Approval",
      "approver_approved_by" => "Review Person (agricultural specialist)"
    })
    ModuleRecord.create!(module_slug: "jeevika-jankar-bill-approval-history", data: {
      "bill_id" => record.id.to_s, "approval_level" => "First Approval",
      "action" => "Approved", "approver" => "Review Person (agricultural specialist)"
    })

    get "/modules/jeevika-jankar-bill-list", params: { view_id: record.id }
    assert_response :success
    assert_select "h2", text: "Jeevika Jankar Bill Details"
    assert_select "td", text: "Farmer One"
    assert_select ".approval-progress-card p", text: "Review Person (Agricultural Specialist)"
  end
end
