require "test_helper"

class TrainingEditApprovalTest < ActiveSupport::TestCase
  test "CC edits route to the owning Agronomist without an approval channel" do
    record = ModuleRecord.create!(module_slug: "training-form", data: { "fco_name" => "FCO-C Sausar", "month" => "August", "training_location" => "Original", "selected_farmer_ids" => ["1"] })
    fco = User.create!(user_name: "sausar_fco", password: "secret", first_name: "Sausar", last_name: "Approver",
      stakeholder_role: "Agronomist", office_name: "FCO-C Sausar")
    approver = { "id" => fco.id, "record_type" => "User", "user_type" => "user", "username" => fco.user_name }
    cc = { "id" => "10", "record_type" => "User", "username" => "cc_user", "name" => "CC Display Name" }
    revision = TrainingEditApproval.submit!(record: record, proposed: record.data.merge("training_location" => "Changed", "selected_farmer_ids" => ["1", "2"]), actor: cc)

    assert_equal "Original", record.reload.data["training_location"]
    assert_equal "Pending", revision.data["status"]
    assert_equal "Pending at Sausar Approver", TrainingEditApproval.status_label(revision)
    assert TrainingEditApproval.can_decide?(revision, approver)

    TrainingEditApproval.decide!(revision: revision, actor: approver, decision: "approve", remarks: "Verified")

    assert_equal "Changed", record.reload.data["training_location"]
    assert_equal %w[1 2], record.data["selected_farmer_ids"]
    assert_equal "Approved", revision.reload.data["status"]
    assert_equal "Approved", TrainingEditApproval.status_label(revision)
  end

  test "routing uses original office and account identity, not edited office or matching names" do
    fco = User.create!(user_name: "own_fco", password: "secret", first_name: "Same Name",
      stakeholder_role: "Agronomist", office_name: "FCO-C Sausar")
    other = User.create!(user_name: "other_fco", password: "secret", first_name: "Same Name",
      stakeholder_role: "Agronomist", office_name: "FCO-C Turekela")
    record = ModuleRecord.create!(module_slug: "training-form", data: { "fco_name" => "FCO-C Sausar" })
    revision = TrainingEditApproval.submit!(record: record, proposed: { "fco_name" => "FCO-C Turekela" },
      actor: { "id" => "99999", "record_type" => "User" })
    assert_equal ["User:#{fco.id}"], revision.data["approver_identities"]
    refute TrainingEditApproval.visible?(revision, { "id" => other.id, "record_type" => "User", "name" => "Same Name" })
    refute TrainingEditApproval.can_decide?(revision, { "id" => other.id, "record_type" => "User", "name" => "Same Name" })
  end

  test "unassigned old request automatically finds its FCO" do
    fco = User.create!(user_name: "legacy_fco", password: "secret", first_name: "Legacy",
      role: "Agronomist", office_name: "FCO-C Sausar")
    revision = ModuleRecord.create!(module_slug: TrainingEditApproval::SLUG, data: {
      "status" => "Pending", "before" => { "fco_name" => "FCO-C Sausar" }, "approvers" => [], "requester" => {} })
    TrainingEditApproval.assign_automatic_approver!(revision)
    assert_equal ["User:#{fco.id}"], revision.reload.data["approver_identities"]
  end

  test "pending FCO request is reassigned to Agronomist" do
    user = User.create!(user_name: "replacement_agronomist", password: "secret", first_name: "Shailesh",
      role: "Agronomist", office_name: "FCO-C Sausar")
    revision = ModuleRecord.create!(module_slug: TrainingEditApproval::SLUG, data: {
      "status" => "Pending", "step" => 0, "before" => { "fco_name" => "FCO-C Sausar" },
      "requester" => {}, "approvers" => ["Hemant Shakkarpude"], "approver_identities" => ["User:99999"] })
    TrainingEditApproval.assign_automatic_approver!(revision)
    assert_equal ["Shailesh"], revision.reload.data["approvers"]
    assert_equal "agronomist", revision.data["approval_role"]
    refute TrainingEditApproval.can_decide?(revision, { "id" => 99999, "record_type" => "User" })
    assert TrainingEditApproval.can_decide?(revision, { "id" => user.id, "record_type" => "User" })
  end

  test "missing FCO does not create an unrouted request" do
    record = ModuleRecord.create!(module_slug: "training-form", data: { "fco_name" => "Unassigned Office" })
    assert_no_difference('ModuleRecord.where(module_slug: TrainingEditApproval::SLUG).count') do
      assert_raises(TrainingEditApproval::InvalidTransition) do
        TrainingEditApproval.submit!(record: record, proposed: record.data, actor: { "id" => "99999" })
      end
    end
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
