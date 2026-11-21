require "test_helper"

class BillSummaryLoadingTest < ActiveSupport::TestCase
  test "bill summary preserves fields item order legacy shapes and source data" do
    shapes = [
      { "bill_items" => [{ "amount" => 12, "farmer_details" => [1, 2], "nested" => { "farmer_details" => "retain" } }, { "amount" => 7 }], "label" => "किसान", "status" => "Pending" },
      { "bill_items" => [] }, { "bill_items" => nil }, { "bill_items" => "legacy" },
      { "bill_items" => { "amount" => 8 } }, { "amount" => 9 }
    ]
    records = shapes.map { |data| ModuleRecord.create!(module_slug: "jeevika-jankar-bill-process", data: data) }
    controller = ModulesController.new
    base = ModuleRecord.where(id: records.map(&:id)).order(id: :desc)
    rows = controller.send(:bill_summary_scope, base).to_a
    assert_equal records.reverse.map(&:id), rows.map(&:id)
    rows.zip(records.reverse, shapes.reverse).each do |row, original, data|
      expected = data.deep_dup
      if expected["bill_items"].is_a?(Array)
        expected["bill_items"].each { |item| item.delete("farmer_details") }
      end
      assert_equal expected, row.data
      assert_equal data, original.reload.data, "Summary reads must not change saved bill data"
      assert_equal original.created_at, row.created_at
      assert_equal original.updated_at, row.updated_at
      assert_equal original.module_slug, row.module_slug
    end
  end
end
