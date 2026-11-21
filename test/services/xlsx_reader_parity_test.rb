require "test_helper"
require "tempfile"
require "zip"
require "rexml/document"

class XlsxReaderParityTest < ActiveSupport::TestCase
  test "all upload readers retain shared strings inline text sparse cells formulas and blanks" do
    with_workbook do |path|
      readers.each do |reader, method|
        rows = reader.send(method, path)
        assert_equal [ "किसान & Farmer", nil, " Rich text ", "12.50", nil, "9", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, "Last" ], rows.first, reader.to_s
        assert_equal [ nil, "line\nbreak" ], rows.second, reader.to_s
        assert_equal [], rows.third, reader.to_s
      end
    end
  end

  test "split text and CDATA keep the legacy first-text-node interpretation" do
    rows = '<row><c r="A1"><v>4<![CDATA[2]]>0</v></c><c r="B1" t="inlineStr"><is><t>First<![CDATA[Second]]>Third</t></is></c><c r="C1" t="s"><v>2</v></c></row>'
    with_workbook(rows: rows) do |path|
      readers.each do |reader, method|
        assert_equal [ [ "4", "First", "Shared" ] ], reader.send(method, path), reader.to_s
      end
    end
  end

  test "internal entities retain the legacy expanded text values" do
    rows = '<row><c r="A1"><v>Before&value;After</v></c><c r="B1" t="inlineStr"><is><t>&value;</t></is></c></row>'
    with_workbook(rows: rows, declaration: '<!DOCTYPE worksheet [<!ENTITY value "Value">]>') do |path|
      readers.each do |reader, method|
        assert_equal [ [ "BeforeValueAfter", "Value" ] ], reader.send(method, path), reader.to_s
      end
    end
  end

  test "malformed worksheet errors retain the original parser exception type" do
    with_workbook(rows: "<row>") do |path|
      readers.each do |reader, method|
        assert_raises(REXML::ParseException) { reader.send(method, path) }
      end
    end
  end

  test "payment workbook retains fallback sheet and missing cell reference handling" do
    with_workbook(sheet: "sheet2.xml", rows: '<row><c t="inlineStr"><is><t>First</t></is></c><c><v>2</v></c></row>') do |path|
      assert_equal [ [ "First", "2" ] ], JeevikaPaymentBulkUpload.allocate.send(:xlsx_rows, path)
      readers.first(4).each do |reader, method|
        error = assert_raises(ArgumentError) { reader.send(method, path) }
        assert_equal "Could not find first sheet in the Excel file.", error.message
      end
    end
  end

  private

  def readers
    [
      [ SaleRecord, :rows_from_xlsx ],
      [ FarmerFarmInformation, :rows_from_xlsx ],
      [ LgDirectoryImporter, :rows_from_xlsx ],
      [ JjQuizQuestionImporter.allocate, :rows_from_xlsx ],
      [ JeevikaPaymentBulkUpload.allocate, :xlsx_rows ]
    ]
  end

  def with_workbook(sheet: "sheet1.xml", rows: nil, declaration: "")
    rows ||= <<~XML
      <row r="1"><c r="A1" t="s"><v>0</v></c><c r="C1" t="inlineStr"><is><r><t xml:space="preserve"> Rich </t></r><r><t>text </t></r></is></c><c r="D1"><v>12.50</v></c><c r="E1"/><c r="F1"><f>3*3</f><v>9</v></c><c r="AA1" t="s"><v>1</v></c></row>
      <row r="2"><c r="B2" t="inlineStr"><is><t>line
      break</t></is></c></row><row r="3"/>
    XML
    Tempfile.create([ "xlsx-parity", ".xlsx" ]) do |file|
      Zip::OutputStream.open(file.path) do |zip|
        zip.put_next_entry("xl/worksheets/#{sheet}")
        zip.write(declaration + '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' + rows + "</sheetData></worksheet>")
        zip.put_next_entry("xl/sharedStrings.xml")
        zip.write('<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>किसान &amp; Farmer</t></si><si><r><t>La</t></r><r><t>st</t></r></si><si><t>Shared<![CDATA[Split]]>Tail</t></si></sst>')
      end
      yield file.path
    end
  end
end
