require "test_helper"

class TrainingApprovalLoadingTest < ActiveSupport::TestCase
  test "summary retains decisions and visibility without loading evidence or staff" do
    actor = { "id" => "81001", "record_type" => "User", "user_type" => "user" }
    data = { "status" => "Pending", "approval_role" => "agronomist", "step" => 0,
      "record_id" => "123", "approver_identities" => ["User:81001"], "approvers" => ["Reviewer"],
      "requester_identity" => "User:81002", "before" => { "location" => "Old" },
      "proposed" => { "location" => "New" }, "history" => [], "evidence" => [{ "base64" => "x" * 100_000 }] }
    revision = ModuleRecord.create!(module_slug: TrainingEditApproval::SLUG, data: data)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = args.last
      queries << payload[:sql] if payload[:name] != "SCHEMA" && !payload[:cached] && payload[:sql].match?(/SELECT/i)
    end
    summaries = ActiveRecord::Base.uncached { TrainingEditApproval.summaries_for(actor, pending_only: true) }
    ActiveSupport::Notifications.unsubscribe(subscriber)
    assert_equal 1, queries.size
    assert_equal [revision.id], summaries.map(&:id)
    assert_equal data.except("before", "proposed", "history", "evidence"), summaries.first.data
    assert summaries.first.readonly?
    assert TrainingEditApproval.can_decide?(summaries.first, actor)
    assert_empty TrainingEditApproval.summaries_for(actor.merge("id" => "999"), pending_only: true)
    assert_equal [revision.id], TrainingEditApproval.summaries_for(actor.merge("id" => "81002"), pending_only: true).map(&:id)
    assert_equal data, revision.reload.data
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "legacy routing preserves full snapshots and picks up later staff assignment" do
    data = { "status" => "Pending", "before" => { "fco_name" => "Performance office" },
      "proposed" => { "location" => "New" }, "evidence" => [{ "base64" => "evidence" }],
      "history" => [], "requester" => {}, "approvers" => [] }
    revision = ModuleRecord.create!(module_slug: TrainingEditApproval::SLUG, data: data)
    admin = { "id" => "90000", "user_type" => "admin" }
    assert_empty TrainingEditApproval.summaries_for(admin, pending_only: true).first.data["approvers"]
    staff = User.create!(user_name: "perf-agronomist", password: "secret", first_name: "Approver",
      role: "Agronomist", office_name: "Performance office")
    summary = TrainingEditApproval.summaries_for(admin, pending_only: true).first
    assert_equal ["User:#{staff.id}"], summary.data["approver_identities"]
    %w[before proposed evidence history].each { |key| assert_equal data[key], revision.reload.data[key] }
  end
end
