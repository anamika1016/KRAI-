require "test_helper"
require "nokogiri"

class StreamingXlsxExporterTest < ActiveSupport::TestCase
  test "streaming preserves cells and workbook metadata without eagerly reading rows" do
    headers = [ "Name", "Evidence", "Number" ]
    data = [ [ "  Hindi किसान & <text>\nnext", "https://example.test/file?a=1&b=2", 12 ],
      [ "=SUM(A1)", nil, "00123" ], [ "quote\"", "comma,value", "" ] ]
    read_rows = false
    rows = Enumerator.new { |output| read_rows = true; data.each { |row| output << row } }
    parts = XlsxExporter.stream(headers: headers, rows: rows, sheet_name: "Training/Form").each
    first = parts.next
    assert_not read_rows
    assert_equal "PK\x03\x04".b, first.byteslice(0, 4)
    body = first.dup
    loop { body << parts.next }
    assert read_rows
    expected = XlsxExporter.generate(headers: headers, rows: data, sheet_name: "Training/Form")
    Zip::File.open_buffer(expected) do |old_zip|
      Zip::File.open_buffer(body) do |zip|
        assert_equal old_zip.entries.map(&:name), zip.entries.map(&:name)
        old_sheet = Nokogiri::XML(old_zip.read("xl/worksheets/sheet1.xml"))
        new_sheet = Nokogiri::XML(zip.read("xl/worksheets/sheet1.xml"))
        assert_empty new_sheet.errors
        assert_equal old_sheet.xpath("//*[local-name()='row']").map(&:to_xml),
          new_sheet.xpath("//*[local-name()='row']").map(&:to_xml)
        assert_equal old_zip.read("xl/workbook.xml"), zip.read("xl/workbook.xml")
        assert_equal Zip::Entry::DEFLATED, zip.find_entry("xl/worksheets/sheet1.xml").compression_method
      end
    end
  end
end
