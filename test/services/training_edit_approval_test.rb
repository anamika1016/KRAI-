require "test_helper"

class TrainingEditApprovalTest < ActiveSupport::TestCase
  test "an approved CC change updates the record only after the configured approver acts" do
    record = ModuleRecord.create!(module_slug: "training-form", data: { "month" => "August", "training_location" => "Original", "selected_farmer_ids" => ["1"] })
    ModuleRecord.create!(module_slug: "approval-master", data: {
      "module_name" => "Training Form Edit", "user_name" => "CC Display Name", "approver_approved_by" => "agronomist_user",
      "approval_level" => "Level 1", "status" => "Active"
    })
    cc = { "id" => "10", "record_type" => "User", "username" => "cc_user", "name" => "CC Display Name" }
    revision = TrainingEditApproval.submit!(record: record, proposed: record.data.merge("training_location" => "Changed", "selected_farmer_ids" => ["1", "2"]), actor: cc)

    assert_equal "Original", record.reload.data["training_location"]
    assert_equal "Pending", revision.data["status"]
    assert_equal "Pending at agronomist_user", TrainingEditApproval.status_label(revision)
    assert TrainingEditApproval.can_decide?(revision, { "user_type" => "user", "username" => "agronomist_user" })

    TrainingEditApproval.decide!(revision: revision, actor: { "user_type" => "user", "username" => "agronomist_user" }, decision: "approve", remarks: "Verified")

    assert_equal "Changed", record.reload.data["training_location"]
    assert_equal %w[1 2], record.data["selected_farmer_ids"]
    assert_equal "Approved", revision.reload.data["status"]
    assert_equal "Approved", TrainingEditApproval.status_label(revision)
  end

  test "approver identified by display name and extra spaces can still decide" do
    revision = ModuleRecord.new(data: {
      "status" => "Pending", "step" => 0,
      "approvers" => ["Shailesh  Bagde (agricultural specialist)"]
    })
    # Login username is just "Shailesh" while the channel stored the full display name.
    approver = { "user_type" => "user", "username" => "Shailesh", "name" => "Shailesh  Bagde", "mobile_no" => "7000280864" }
    submitter = { "user_type" => "user", "username" => "Ashvin", "name" => "Ashvin  Durve" }

    assert TrainingEditApproval.can_decide?(revision, approver), "the named approver should be able to decide"
    assert TrainingEditApproval.visible?(revision, approver)
    refute TrainingEditApproval.can_decide?(revision, submitter), "the submitter must not decide"
  end
end
