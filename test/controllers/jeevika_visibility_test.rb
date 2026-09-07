require "test_helper"

class JeevikaVisibilityTest < ActiveSupport::TestCase
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
    controller.define_singleton_method(:current_app_user) { { "fcoc" => "Shared FCO", "to_name" => "Turekela" } }
    refute controller.send(:jeevika_bill_vrp_office_visible?, Vrp.new(fcoc: "Shared FCO", to_name: "Sausar"))
    assert controller.send(:jeevika_bill_vrp_office_visible?, Vrp.new(fcoc: "Shared FCO", to_name: "Turekela"))
  end

  test "mapped report uses all farmer columns and query status fields" do
    controller = ModulesController.new
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
