require "test_helper"
require "benchmark"

# Afl.rows_from_xlsx used to walk the sheet with REXML XPath, re-scanning the
# whole tree for every row and every cell inside it -- a 1,000-row file alone
# took 28s to parse, so a real AFL import (tens of thousands of rows) timed
# out the upload long before the database work even started. It now streams
# the sheet with Nokogiri::XML::SAX instead; these tests lock in that the
# streamed output still matches what the old DOM walk produced.
class AflImportXlsxPerformanceTest < ActiveSupport::TestCase
  FakeUpload = Struct.new(:original_filename, :path)

  test "shared strings, inline strings, numbers and blank cells all parse correctly" do
    xlsx_path = build_xlsx(
      shared_strings: ["Farmer_Name", "FCO_ID", "FCO", "Total_Farm_Area", "Ramesh Kumar", "Sausar"],
      # Row 1 (header) uses shared strings 0..2; Row 2 mixes a shared string
      # name (4), a numeric FCO id written inline (not shared), a shared FCO
      # name (5), and a decimal farm area -- with column D (index 3) entirely
      # skipped, the way Excel omits genuinely empty cells.
      rows: [
        [{ type: :shared, value: 0 }, { type: :shared, value: 1 }, { type: :shared, value: 2 }],
        [{ type: :shared, value: 4 }, { type: :inline, value: "1004" }, { type: :shared, value: 5 }, nil, { type: :inline, value: "2.5" }]
      ]
    )

    begin
      rows = Afl.send(:rows_from_xlsx, xlsx_path)
      assert_equal 2, rows.size
      assert_equal ["Farmer_Name", "FCO_ID", "FCO"], rows[0]
      assert_equal ["Ramesh Kumar", "1004", "Sausar", nil, "2.5"], rows[1]
    ensure
      File.delete(xlsx_path) if File.exist?(xlsx_path)
    end
  end

  test "a full import through Afl.import persists shared-string rows" do
    xlsx_path = build_xlsx(
      shared_strings: ["Farmer_Name", "FCO_ID", "FCO", "Sunita Devi", "Turekela"],
      rows: [
        [{ type: :shared, value: 0 }, { type: :shared, value: 1 }, { type: :shared, value: 2 }],
        [{ type: :shared, value: 3 }, { type: :inline, value: "1006" }, { type: :shared, value: 4 }]
      ]
    )

    begin
      result = Afl.import(FakeUpload.new("upload.xlsx", xlsx_path))
      assert_equal 1, result[:imported], result.inspect
      imported = Afl.order(id: :desc).first
      assert_equal "Sunita Devi", imported.farmer_name
      assert_equal "1006", imported.fco_id
      assert_equal "Turekela", imported.fco
    ensure
      File.delete(xlsx_path) if File.exist?(xlsx_path)
    end
  end

  test "parsing a few thousand rows stays fast" do
    n = 2000
    rows = [[{ type: :inline, value: "Farmer_Name" }, { type: :inline, value: "FCO_ID" }]] +
      n.times.map { |i| [{ type: :inline, value: "Farmer #{i}" }, { type: :inline, value: "1004" }] }
    xlsx_path = build_xlsx(shared_strings: [], rows: rows)

    begin
      elapsed = Benchmark.realtime { Afl.send(:rows_from_xlsx, xlsx_path) }
      assert_operator elapsed, :<, 5, "parsing #{n} rows took #{elapsed.round(2)}s -- REXML took 28s for just 1,000"
    ensure
      File.delete(xlsx_path) if File.exist?(xlsx_path)
    end
  end

  private

  # Builds a minimal .xlsx whose xl/worksheets/sheet1.xml and
  # xl/sharedStrings.xml match what Afl.rows_from_xlsx actually reads -- Excel
  # writes a lot more (styles, workbook.xml, content types) that the reader
  # never looks at.
  def build_xlsx(shared_strings:, rows:)
    path = Rails.root.join("tmp", "afl_xlsx_perf_test_#{SecureRandom.hex(4)}.xlsx")
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("xl/sharedStrings.xml")
      zip.write(shared_strings_xml(shared_strings))
      zip.put_next_entry("xl/worksheets/sheet1.xml")
      zip.write(sheet_xml(rows))
    end
    File.binwrite(path, buffer.string)
    path.to_s
  end

  def shared_strings_xml(strings)
    items = strings.map { |s| "<si><t>#{s}</t></si>" }.join
    %(<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="#{strings.size}" uniqueCount="#{strings.size}">#{items}</sst>)
  end

  def sheet_xml(rows)
    column_letters = ("A".."Z").to_a
    body = rows.each_with_index.map do |cells, row_index|
      row_number = row_index + 1
      cell_xml = cells.each_with_index.filter_map do |cell, col_index|
        next if cell.nil?

        ref = "#{column_letters[col_index]}#{row_number}"
        if cell[:type] == :shared
          %(<c r="#{ref}" t="s"><v>#{cell[:value]}</v></c>)
        else
          %(<c r="#{ref}"><v>#{cell[:value]}</v></c>)
        end
      end.join
      %(<row r="#{row_number}">#{cell_xml}</row>)
    end.join
    %(<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>#{body}</sheetData></worksheet>)
  end
end
