require "test_helper"

class AflTest < ActiveSupport::TestCase
  test "maps Farm_ID Excel header to farm_id" do
    assert_equal :farm_id, Afl.column_for_header("Farm_ID")
    assert_equal :farm_id, Afl.column_for_header("farm id")
  end

  test "imports farm_id from an uploaded row" do
    result = Afl.import_rows([["FARM-101", "Test Farmer"]], ["Farm_ID", "Farmer_Name"])

    assert_equal 1, result[:imported]
    assert_equal "FARM-101", Afl.find_by!(farmer_name: "Test Farmer").farm_id
  end

  test "search matches fields outside the list table columns" do
    marker = SecureRandom.hex(6)
    afl = Afl.create!(
      farmer_name: "Farmer #{marker}",
      purchase_product_type: "Hidden #{marker}"
    )

    assert_includes Afl.search("Hidden #{marker}"), afl
  end
end
