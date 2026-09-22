require "test_helper"

class TrainingEditApprovalsControllerTest < ActionDispatch::IntegrationTest
  test "responsible Agronomist sees and approves automatically routed edit without channel setup" do
    fco = User.create!(user_name: "routing_fco", password: "secret", first_name: "Responsible FCO",
      role: "Agronomist", office_name: "FCO-C Sausar", user_type: "User")
    record = ModuleRecord.create!(module_slug: "training-form", data: {
      "fco_name" => "FCO-C Sausar", "training_location" => "Original" })
    revision = TrainingEditApproval.submit!(record: record,
      proposed: record.data.merge("training_location" => "Changed"),
      actor: { "id" => "99999", "record_type" => "User", "name" => "Requesting CC" })
    post login_path, params: { login: fco.user_name, password: "secret" }
    ModuleRecord.create!(module_slug: TrainingEditApproval::SLUG, data: revision.data.merge("status" => "Approved"))
    get training_edit_approvals_path
    assert_response :success
    assert_select '.sidebar-pending-dot'
    assert_select '.module-table tbody tr:first-child a[href=?]', training_edit_approval_path(revision)
    assert_select 'a[href=?]', training_edit_approval_path(revision)
    assert_select 'a[href=?]', training_edit_approvals_path
    get training_edit_approval_path(revision)
    assert_response :success
    assert_select 'button[value="approve"]'
    patch training_edit_approval_path(revision), params: { decision: "approve", remarks: "Verified" }
    assert_redirected_to training_edit_approval_path(revision)
    assert_equal "Changed", record.reload.data["training_location"]
    assert_equal "Approved", revision.reload.data["status"]
    get training_edit_approvals_path
    assert_response :success
    assert_select '.sidebar-pending-dot', count: 0
  end
end
