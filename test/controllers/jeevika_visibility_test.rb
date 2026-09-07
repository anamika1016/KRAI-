require "test_helper"

class JeevikaVisibilityTest < ActiveSupport::TestCase
  test "cluster cannot see another cluster bill through creator or approval access" do
    controller = policy(cluster: true)
    controller.define_singleton_method(:module_cluster_vrp_visible?) { |_vrp| false }
    controller.define_singleton_method(:jeevika_bill_created_by_current_user?) { |_record| true }
    controller.define_singleton_method(:jeevika_bill_approver_visible?) { |_record| true }
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
