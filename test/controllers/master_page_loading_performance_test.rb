require "test_helper"

class MasterPageLoadingPerformanceTest < ActiveSupport::TestCase
  test "unrelated static fields do not load JJ or sidebar options" do
    controller = ModulesController.new
    controller.define_singleton_method(:vrp_name_options) { raise "unrelated JJ list" }
    controller.define_singleton_method(:sidebar_submodule_names) { raise "unrelated sidebar list" }
    controller.define_singleton_method(:financial_year_options) { raise "unrelated financial years" }
    assert_equal [], controller.send(:static_field_options, "State")
    assert_equal [], controller.send(:static_field_options, "Status")
    assert_equal [ "High", "Medium", "Low" ], controller.send(:static_field_options, "Priority")
    assert_equal [ "Pending", "Paid", "Rejected" ], controller.send(:static_field_options, "Payment Status")
  end

  test "dynamic fields retain their original option values" do
    controller = ModulesController.new
    controller.define_singleton_method(:vrp_name_options) { [ "JJ - 9876543210" ] }
    controller.define_singleton_method(:sidebar_submodule_names) { [ "Module" ] }
    controller.define_singleton_method(:financial_year_options) { [ "2026-2027" ] }
    assert_equal [ "JJ - 9876543210" ], controller.send(:static_field_options, "VRP Name")
    assert_equal [ "Module" ], controller.send(:static_field_options, "Sub Module Name")
    assert_equal [ "2026-2027" ], controller.send(:static_field_options, "Financial Year")
    assert_equal Date::MONTHNAMES.compact, controller.send(:static_field_options, "Month Name")
  end

  test "location lookup cache retains aliases source order missing labels and unmatched values" do
    controller = ModulesController.new
    base = { "state" => "State", "district" => "District", "block" => "Block" }
    data = [
      base.merge("gp_code" => "001", "gram_panchayat_name" => "111"),
      base.merge("gram_code" => "001", "gram_panchayat_name" => "First Match"),
      base.merge("gp_code" => "001", "gram_panchayat_name" => "Later Match"),
      base.merge("gram_panchayat_code" => "missing-label"),
      base.merge("gram_panchayat_code" => "missing-label", "gram_panchayat_name" => "Later Label"),
      base.merge("district" => "Other District", "gp_code" => "001", "gram_panchayat_name" => "Other District Label")
    ]
    records = data.map { |attributes| ModuleRecord.new(module_slug: "gram-panchayat-master", data: attributes) }
    loads = 0
    controller.define_singleton_method(:gram_panchayat_location_records) { loads += 1; records }
    village = ModuleRecord.new(module_slug: "village-master", data: {
      "state_name" => " STATE ", "district_name" => " District ", "cd_block_name" => " block "
    })
    10.times { assert_equal "First Match", controller.send(:gram_panchayat_name_by_location, village, " 001 ") }
    assert_nil controller.send(:gram_panchayat_name_by_location, village, "missing-label")
    assert_nil controller.send(:gram_panchayat_name_by_location, village, "unknown")
    assert_equal "", controller.send(:gram_panchayat_name_by_location, village, "")
    assert_equal "", controller.send(:gram_panchayat_name_by_location, ModuleRecord.new(data: {}), "001")
    village.data["district_name"] = "Other District"
    assert_equal "Other District Label", controller.send(:gram_panchayat_name_by_location, village, "001")
    assert_equal 4, loads
  end

  test "sort field caching preserves field changes and blank zero fallback values" do
    controller = ModulesController.new
    record = ModuleRecord.new(module_slug: "test", data: { "name" => "Alpha", "quantity" => 0, "status" => "Active" })
    controller.instance_variable_set(:@module, { fields: [ "Status", "Name" ] })
    assert_equal "Alpha", controller.send(:module_record_sort_value, record)
    controller.instance_variable_set(:@module, { fields: [ "Quantity", "Name" ] })
    assert_equal 0, controller.send(:module_record_sort_value, record)
    record.data["quantity"] = " "
    assert_equal "Alpha", controller.send(:module_record_sort_value, record)
  end
end
