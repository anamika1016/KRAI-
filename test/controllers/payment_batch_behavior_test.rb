require "test_helper"

class PaymentBatchBehaviorTest < ActiveSupport::TestCase
  test "batch payments retain individual JJ fallback when a target is outside the initial mapping scope" do
    vrps = 2.times.map do |index|
      vrp = Vrp.new(name: "Batch fallback #{index}", email: "batch-fallback-#{index}@example.test",
        aadhar_no: "123456789012", account_no: "1234", address: "Test", branch: "Test",
        date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
        experience_in_years: 1, father_husband_name: "Test", gender: :male,
        ifsc_code: "SBIN0001234", mobile_no: "9876543210", office_detail_id: 1, to_office_detail_id: 1)
      vrp.save!(validate: false)
      TargetMapping.create!(vrp: vrp, fco_id: "1004", ics_id: "batch", village_id: "batch-#{index}",
        month_name: "August", main_activity_name: "Other", activity_name: "Batch fallback",
        target_quantity: index + 3, afl_ids: [])
      vrp
    end
    bills = vrps.map do |vrp|
      ModuleRecord.new(module_slug: "jeevika-jankar-bill-process",
        data: { "select_vrp" => vrp.id.to_s, "bill_month" => "August", "total_target" => "99" })
    end
    build = lambda do
      controller = ModulesController.new
      controller.params = ActionController::Parameters.new
      controller.define_singleton_method(:vrp_login_user?) { false }
      controller.define_singleton_method(:module_mapped_vrp_scope_active?) { true }
      controller.define_singleton_method(:module_cluster_visible_vrp_ids) { [ vrps.first.id ] }
      controller
    end
    # Numeric IDs, legacy names and unmapped saved bills must all retain
    # their individual calculation when a mixed batch cannot resolve them.
    bills += [ ModuleRecord.new(module_slug: "jeevika-jankar-bill-process",
      data: { "select_vrp" => vrps.last.name, "bill_month" => "August", "total_target" => "88" }),
      ModuleRecord.new(module_slug: "jeevika-jankar-bill-process",
        data: { "select_vrp" => "999999999", "bill_month" => "August", "total_target" => "77" }) ]
    expected = bills.map { |bill| build.call.send(:jeevika_jankar_bill_total_target, bill) }
    assert_equal %w[3 4 4 77], expected.map(&:to_s)
    batch = build.call
    batch.send(:preload_jeevika_bill_process_totals, bills, preserve_individual_fallbacks: true)
    assert_equal expected, bills.map { |bill| batch.send(:jeevika_jankar_bill_total_target, bill) }
  end
end
