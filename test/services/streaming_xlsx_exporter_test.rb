require "test_helper"
require "nokogiri"

class StreamingXlsxExporterTest < ActiveSupport::TestCase
  test "workbook uses conventional ZIP headers and real central directory sizes" do
    body = XlsxExporter.stream(headers: [ "Name" ], rows: [ [ "Training" ] ]).each.to_a.join
    assert_equal 20, body.byteslice(4, 2).unpack1("v")
    assert_equal 0, body.byteslice(28, 2).unpack1("v"), "Excel local headers must not contain ZIP64 placeholders"
    footer = body.byteslice(-22, 22).unpack("VvvvvVVv")
    assert_equal 0x06054b50, footer[0]
    assert_equal 8, footer[4]
    assert_equal body.bytesize - 22, footer[5] + footer[6]
    offset = footer[6]
    footer[4].times do
      header = body.byteslice(offset, 46).unpack("VvvvvvvVVVvvvvvVV")
      assert_equal 0x02014b50, header[0]
      assert_equal 20, header[2]
      assert_operator header[8], :<, 0xffffffff
      assert_operator header[9], :<, 0xffffffff
      assert_equal 0, header[11]
      offset += 46 + header[10] + header[11] + header[12]
    end
    assert_equal body.bytesize - 22, offset
    Zip::File.open_buffer(body) do |zip|
      zip.each { |entry| assert_nothing_raised { entry.get_input_stream.read } }
    end
  end

  test "control characters and literal OOXML escapes produce valid worksheet XML" do
    text = "किसान\u0000\u0001\u000B\u000C\u001F\uFFFE literal _x0041_ & <value>\nnext"
    [ XlsxExporter.stream(headers: [ "Name" ], rows: [ [ text ] ]).each.to_a.join,
      XlsxExporter.generate(headers: [ "Name" ], rows: [ [ text ] ]) ].each do |body|
      Zip::File.open_buffer(body) do |zip|
        sheet = Nokogiri::XML(zip.read("xl/worksheets/sheet1.xml")) { |config| config.strict }
        value = sheet.xpath("//*[local-name()='row'][@r='2']//*[local-name()='t']").text
        assert_equal "किसान_x0000__x0001__x000B__x000C__x001F__xFFFE_ literal _x005F_x0041_ & <value>\nnext", value
      end
    end
  end

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
