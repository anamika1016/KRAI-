require "test_helper"

# Excel's "CSV (Comma delimited)" export writes the system's ANSI codepage
# (Windows-1252), not UTF-8. Uploading one 500'd with CSV::InvalidEncodingError
# because Afl.import_csv opened the file with no encoding fallback.
class AflImportEncodingTest < ActiveSupport::TestCase
  FakeUpload = Struct.new(:original_filename, :path)

  test "a Windows-1252 CSV (accented farmer name) imports instead of raising" do
    path = Rails.root.join("tmp", "afl_import_encoding_test_#{SecureRandom.hex(4)}.csv")
    # Windows-1252 has no composed accented-letter byte for every case, so build
    # the file directly from Windows-1252 bytes that are NOT valid UTF-8 on
    # their own -- 0xE9 ("é") is exactly the kind of byte that raised before.
    File.binwrite(path, "Farmer_Name,FCO_ID,FCO\n\xE9l\xE8ve,1004,Sausar\n".dup.force_encoding("ASCII-8BIT"))

    begin
      result = Afl.import(FakeUpload.new("upload.csv", path.to_s))
      assert_equal 1, result[:imported], result.inspect
      imported = Afl.order(id: :desc).first
      assert_equal "élève", imported.farmer_name
    ensure
      File.delete(path) if File.exist?(path)
    end
  end

  test "a plain UTF-8 CSV still imports" do
    path = Rails.root.join("tmp", "afl_import_encoding_test_#{SecureRandom.hex(4)}.csv")
    File.write(path, "Farmer_Name,FCO_ID,FCO\nRamesh Kumar,1004,Sausar\n")

    begin
      result = Afl.import(FakeUpload.new("upload.csv", path.to_s))
      assert_equal 1, result[:imported], result.inspect
      assert_equal "Ramesh Kumar", Afl.order(id: :desc).first.farmer_name
    ensure
      File.delete(path) if File.exist?(path)
    end
  end
end
