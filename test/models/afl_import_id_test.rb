require "test_helper"
require "csv"

# Reported from AFL Upload: the sheet has its own ID column, but the uploaded
# row came back with a different id. "ID" was not in IMPORT_COLUMNS and had no
# header alias, so column_for_header("ID") returned nil and the value was
# dropped -- the row then took a fresh auto-increment id. Target mappings store
# these numbers in afl_ids, so the sheet's id has to survive the upload.
class AflImportIdTest < ActiveSupport::TestCase
  setup do
    @path = Rails.root.join("tmp", "afl_import_id_#{SecureRandom.hex(4)}.csv")
  end

  teardown do
    File.delete(@path) if File.exist?(@path)
  end

  test "the sheet's ID heading maps onto the row id" do
    %w[ID Id id].each do |heading|
      assert_equal :id, Afl.send(:column_for_header, heading), "#{heading} should map to :id"
    end
  end

  test "the uploaded row keeps the ID from the sheet" do
    write_csv([[900101, "Keeps Id"], [900102, "Keeps Id Too"]])

    result = Afl.import_csv(@path.to_s)

    assert_equal 2, result[:imported]
    assert_empty result[:skipped]
    assert_equal [900101, 900102], Afl.where(id: [900101, 900102]).order(:id).pluck(:id)
    assert_equal "Keeps Id", Afl.find(900101).farmer_name
  end

  test "a blank ID still falls back to the database's own id" do
    write_csv([[nil, "No Id Given"]])

    assert_equal 1, Afl.import_csv(@path.to_s)[:imported]
    row = Afl.find_by(farmer_name: "No Id Given")
    assert row.present?, "the row must still import"
    assert row.id.present?
  end

  test "a non-numeric ID is ignored rather than breaking the upload" do
    write_csv([["not-a-number", "Junk Id"]])

    assert_equal 1, Afl.import_csv(@path.to_s)[:imported]
    assert Afl.find_by(farmer_name: "Junk Id").present?
  end

  # Without this the next row saved with no id would reuse an id that already
  # exists and the insert would fail.
  test "the id sequence is pushed past the highest imported id" do
    write_csv([[900201, "Sequence Check"]])
    Afl.import_csv(@path.to_s)

    follower = Afl.create!(farmer_name: "After The Import", fco_id: "1004")
    assert_operator follower.id, :>, 900201,
      "a later auto id must not collide with the imported one"
  end

  private

  def write_csv(rows)
    CSV.open(@path, "w") do |csv|
      csv << %w[ID FCO_ID Farmer_Name]
      rows.each { |id, name| csv << [id, "1004", name] }
    end
  end
end

# The upload kept the sheet's id, but searching for it found nothing: id was
# excluded from searchable_columns, so the ID heading filter was dropped on the
# floor and the list came back unfiltered.
class AflIdSearchableTest < ActiveSupport::TestCase
  setup do
    @row = Afl.create!(id: 178026, farmer_name: "Arun Mahadev Khode", fco_id: "1004",
      tracenet_no: "850363940030")
    Afl.create!(id: 178047, farmer_name: "Someone Else", fco_id: "1004", tracenet_no: "925223065351")
  end

  test "id is searchable" do
    assert_includes Afl.send(:searchable_columns).map(&:to_s), "id"
  end

  test "timestamps stay out of the search" do
    %w[created_at updated_at].each do |column|
      refute_includes Afl.send(:searchable_columns).map(&:to_s), column
    end
  end

  test "the ID heading filter finds the row by the sheet's id" do
    %w[contains equals starts].each do |operator|
      found = Afl.column_filtered({ "id" => "178026" }, { "id" => operator })
      assert_equal [178026], found.pluck(:id), "operator #{operator} should find the row"
    end
  end

  test "the ID filter still narrows rather than returning everything" do
    assert_equal 1, Afl.column_filtered({ "id" => "178026" }, { "id" => "equals" }).count
    assert_operator Afl.count, :>, 1, "there is more than one row to narrow from"
  end

  test "the search-any-field box finds a row by its id too" do
    assert_includes Afl.search("178026").pluck(:id), 178026
  end
end
