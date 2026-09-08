require "test_helper"

class JeevikaVisibilityTest < ActiveSupport::TestCase
  test "completed payment visibility uses JJ assignment even when user approved the bill" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    controller.define_singleton_method(:admin_dashboard_user?) { false }
    controller.define_singleton_method(:cached_vrp_lookup) { |id| Vrp.new(id: id) }
    controller.define_singleton_method(:scoped_jeevika_vrp_visible?) { |vrp| vrp&.id == 12 }
    controller.define_singleton_method(:jeevika_jankar_bill_record_visible?) { |_| true }
    assert controller.send(:jeevika_completed_payment_item_visible?, { "jeevika_jankar_id" => "12", "bill_id" => "1" })
    refute controller.send(:jeevika_completed_payment_item_visible?, { "jeevika_jankar_id" => "13", "bill_id" => "2" })
    refute controller.send(:jeevika_completed_payment_item_visible?, {})
  end

  test "bill summaries batch multiple JJ records in one calculation per month" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    calls = []
    controller.define_singleton_method(:jeevika_jankar_bill_rows) do |vrp_id:, month_name:|
      calls << [vrp_id, month_name]
      @jeevika_jankar_target_summary = { "12" => { "july" => { target: "40", achievement: "30" } }, "13" => { "july" => { target: "20", achievement: "10" } } }
    end
    records = %w[12 13].map { |id| ModuleRecord.new(data: { "select_vrp" => id, "bill_month" => "July" }) }
    controller.send(:preload_jeevika_bill_process_totals, records)
    assert_equal [["12,13", "July"]], calls
    assert_equal "40", controller.send(:jeevika_jankar_bill_total_target, records.first)
    assert_equal "10", controller.send(:jeevika_jankar_bill_total_achievement, records.last)
    assert_equal 1, calls.size
  end

  test "approver names remove repeated wrappers without losing the role" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    name = "Shailesh Bagde"
    original = "#{name} (agricultural specialist)"
    expected = "#{name} (Agricultural specialist)"
    [original, "#{name} (#{original})", "#{name} (#{name} (#{original}))"].each do |label|
      assert_equal expected, controller.send(:jeevika_bill_approver_display_name, label, name)
    end
    assert_equal "Hemant Shakkarpude", controller.send(:jeevika_bill_approver_display_name, nil, "Hemant Shakkarpude")
  end

  test "equivalent approval levels appear once with the latest approver" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    history = ["First Approval", " First  Approval ", "Level 1"].map.with_index do |level, index|
      ModuleRecord.new(id: index + 1, created_at: Time.zone.parse("2026-07-06 12:00") + index.minutes, data: {
        "action" => "Approved", "approval_level" => level,
        "approver" => "Person #{index} (Specialist)"
      })
    end
    controller.define_singleton_method(:jeevika_bill_approval_history) { |_record| history }
    rows = controller.send(:jeevika_bill_approved_by_rows, ModuleRecord.new(data: {}))
    assert_equal 1, rows.size
    assert_equal "Person 2 (Specialist)", rows.first[1]
  end

  test "approver headings preserve historical levels when the current channel changes" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    steps = [
      ["First Approval", "Shailesh  Bagde (agricultural specialist)"],
      ["Second Approval", "Hemant Shakkarpude (FCO-C Sausar)"],
      ["Third Approval", "Dr Noushad Parvez (Assistant General Manager)"],
      ["Fourth Approval", "Gaurav Mittal (Chief Financial Officer, PAPL)"]
    ].map { |level, approver| ModuleRecord.new(data: { "approval_level" => level, "approver_approved_by" => approver }) }

    # Channel changed after these were approved, so the stored levels are one short.
    history = [
      ["First Approval", "Hemant Shakkarpude (FCO-C Sausar)", "2026-07-06T07:55:41Z"],
      ["Second Approval", "Dr Noushad Parvez (Assistant General Manager)", "2026-07-06T13:30:09Z"],
      ["Third Approval", "Gaurav Mittal (Chief Financial Officer, PAPL)", "2026-07-09T10:51:17Z"]
    ].map.with_index do |(level, approver, at), index|
      ModuleRecord.new(id: index + 1, data: {
        "action" => "Approved", "approval_level" => level, "approver" => approver, "action_at" => at
      })
    end

    controller.define_singleton_method(:jeevika_bill_approval_steps) { |_record| steps }
    controller.define_singleton_method(:jeevika_bill_approval_history) { |_record| history }

    rows = controller.send(:jeevika_bill_approved_by_rows, ModuleRecord.new(data: { "status" => "Final Approved" }))
    assert_equal ["First Approval", "Second Approval", "Finance Approval"], rows.map(&:first)
    assert_equal "Hemant Shakkarpude (FCO-C Sausar)", rows.first[1]
  end

  test "total payment falls back to the fixed amount when the saved amount is zero" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    fixed = format("%.2f", ModulesController::JEEVIKA_JANKAR_BILL_FIXED_TOTAL)
    ["0.00", "0", "", nil].each do |stored|
      record = ModuleRecord.new(data: { "grand_total" => stored })
      assert_equal fixed, controller.send(:jeevika_jankar_bill_total_payment, record)
    end
    record = ModuleRecord.new(data: { "grand_total" => "4200.00" })
    assert_equal "4200.00", controller.send(:jeevika_jankar_bill_total_payment, record)
  end

  test "legacy bill without created_by resolves the channel of whoever sent it" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    submitter = User.new(user_name: "Ashvin", first_name: "Ashvin", last_name: "Durve", stakeholder: "PAPL")
    history = [
      ModuleRecord.new(id: 2, data: { "action" => "Sent for Approval", "action_by" => "Ashvin  Durve", "action_at" => "2026-07-02T12:06:17Z" }),
      ModuleRecord.new(id: 1, data: { "action" => "Sent for Approval", "action_by" => "Ashvin  Durve", "action_at" => "2026-07-02T12:05:23Z" })
    ]
    controller.define_singleton_method(:jeevika_bill_approval_history) { |_record| history }
    controller.define_singleton_method(:model_ready?) { |_model| true }
    controller.define_singleton_method(:bill_submitter_user) { |_label| submitter }

    identity = controller.send(:bill_submitter_identity, ModuleRecord.new(data: {}))
    assert_equal "Ashvin", identity[:user_name]
    assert_equal "PAPL", identity[:stakeholder]

    controller.define_singleton_method(:jeevika_bill_approval_history) { |_record| [] }
    assert_nil controller.send(:bill_submitter_identity, ModuleRecord.new(data: {}))
  end

  test "bill list totals use the process summary and cache it for the VRP month" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    calls = []
    controller.define_singleton_method(:jeevika_jankar_bill_rows) do |vrp_id:, month_name:|
      calls << [vrp_id, month_name]
      @jeevika_jankar_target_summary = { "12" => { "july" => { target: "50", achievement: "35" } } }
      []
    end
    record = ModuleRecord.new(data: {
      "select_vrp" => "12", "bill_month" => "July",
      "bill_items" => [{ "assigned_count" => "10", "achievement_count" => "2" }]
    })
    assert_equal "50", controller.send(:jeevika_jankar_bill_total_target, record)
    assert_equal "35", controller.send(:jeevika_jankar_bill_total_achievement, record)
    assert_equal [["12", "July"]], calls
    assert_nil controller.instance_variable_get(:@jeevika_jankar_target_summary)
  end

  test "cluster sees its own bills even after JJ assignment changes" do
    controller = policy(cluster: true)
    controller.define_singleton_method(:module_cluster_vrp_visible?) { |_vrp| false }
    controller.define_singleton_method(:jeevika_bill_created_by_current_user?) { |_record| true }
    controller.define_singleton_method(:jeevika_bill_approver_visible?) { |_record| true }
    %w[Pending FinalApproved].each do |status|
      assert controller.send(:jeevika_jankar_bill_record_visible?, ModuleRecord.new(data: { "select_vrp" => "1", "status" => status }))
    end
    controller.define_singleton_method(:jeevika_bill_created_by_current_user?) { |_record| false }
    refute controller.send(:jeevika_jankar_bill_record_visible?, ModuleRecord.new(data: { "select_vrp" => "1" }))
  end

  test "agronomist sees only registrations belonging to that user" do
    controller = policy(agronomist: true)
    controller.define_singleton_method(:jeevika_bill_vrp_registered_by_current_user?) { |vrp| vrp.id == 1 }
    assert controller.send(:scoped_jeevika_vrp_visible?, Vrp.new(id: 1))
    refute controller.send(:scoped_jeevika_vrp_visible?, Vrp.new(id: 2))
  end

  test "FCO office match does not override a different territory" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    controller.define_singleton_method(:current_app_user) { { "fcoc" => "Shared FCO", "to_name" => "Turekela" } }
    refute controller.send(:jeevika_bill_vrp_office_visible?, Vrp.new(fcoc: "Shared FCO", to_name: "Sausar"))
    assert controller.send(:jeevika_bill_vrp_office_visible?, Vrp.new(fcoc: "Shared FCO", to_name: "Turekela"))
  end

  test "mapped report uses all farmer columns and query status fields" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    controller.define_singleton_method(:admin_dashboard_user?) { true }
    controller.send(:farmer_training_participation_rows_from_sql, "unique", month_name: "August", fcoc_name: "1004")
    result = controller.instance_variable_get(:@mapped_farmer_details)
    assert result
    %w[vrp_id vrp_name cluster_incharge main_activity_type status activity_mapped training_mapped training_entry_done farmer_status].each do |column|
      assert_includes result.columns, column
    end
    assert_empty Afl.column_names - result.columns
  end

  test "FCOC sees all territories of its FCO and excludes another FCO" do
    controller = policy
    controller.define_singleton_method(:dashboard_source_fcoc_login?) { true }
    controller.define_singleton_method(:current_app_user) { { "office_name" => "FCO-C Sausar", "office" => "TO -Sausar" } }
    assert controller.send(:scoped_jeevika_vrp_visible?, Vrp.new(fcoc: "FCO-C Sausar", to_name: "TO Other"))
    refute controller.send(:scoped_jeevika_vrp_visible?, Vrp.new(fcoc: "FCO-C Turekela", to_name: "TO -Sausar"))
  end

  test "bill creator identity survives username changes" do
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    controller.define_singleton_method(:current_app_user) { { "id" => 14, "record_type" => "User", "username" => "renamed" } }
    record = ModuleRecord.new(data: { "created_by_id" => "14", "created_by_record_type" => "User", "created_by_username" => "old" })
    assert controller.send(:jeevika_bill_created_by_current_user?, record)
    record.data["created_by_id"] = "15"
    refute controller.send(:jeevika_bill_created_by_current_user?, record)
  end

  test "no training report includes unmapped farmers and ignores other activity entries" do
    untrained = Afl.create!(farmer_name: "Untrained", fco_id: "1004")
    completed = Afl.create!(farmer_name: "Completed", fco_id: "1004")
    elsewhere = Afl.create!(farmer_name: "Elsewhere", fco_id: "1006")
    ModuleRecord.create!(module_slug: "training-form", data: {
      "month" => "August", "main_activity" => "Other Activity", "main_activity_type" => "Other",
      "selected_farmer_ids" => [untrained.id.to_s]
    })
    ModuleRecord.create!(module_slug: "training-form", data: {
      "month" => "August", "main_activity" => "Farmers' Training", "main_activity_type" => "Training",
      "selected_farmer_ids" => [completed.id.to_s]
    })
    controller = ModulesController.new
    controller.params = ActionController::Parameters.new
    controller.define_singleton_method(:admin_dashboard_user?) { true }
    controller.send(:farmer_training_participation_rows_from_sql, "red", month_name: "August", fcoc_name: "1004")
    result = controller.instance_variable_get(:@mapped_farmer_details)
    assert result
    ids = result.map { |row| row["id"].to_s }
    assert_includes ids, untrained.id.to_s
    refute_includes ids, completed.id.to_s
    refute_includes ids, elsewhere.id.to_s
    row = result.find { |item| item["id"].to_s == untrained.id.to_s }
    assert_equal "No Activity Mapping", row["status"]
    assert_equal "No", row["training_entry_done"]
    assert_equal "Red", row["farmer_status"]
    assert_empty Afl.column_names - result.columns
  end

  private

  def policy(cluster: false, agronomist: false)
    ModulesController.new.tap do |controller|
      controller.define_singleton_method(:admin_dashboard_user?) { false }
      controller.define_singleton_method(:vrp_login_user?) { false }
      controller.define_singleton_method(:dashboard_agronomics_login?) { agronomist }
      controller.define_singleton_method(:dashboard_source_fcoc_login?) { false }
      controller.define_singleton_method(:module_cluster_incharge_login?) { cluster }
      controller.define_singleton_method(:jeevika_bill_vrp_for_visibility) { |_record| Vrp.new(id: 1) }
    end
  end
end
