require "test_helper"
require "tmpdir"

class StreamingAttachmentZipTest < ActiveSupport::TestCase
  test "streams before enumerating files and reads attachments in bounded chunks" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "photo.jpg")
      content = "x".b * (StreamingAttachmentZip::CHUNK_SIZE * 3 + 7)
      File.binwrite(path, content)
      enumerated = false
      paths = Enumerator.new { |output| enumerated = true; output << path }
      chunks = StreamingAttachmentZip.new(paths).each
      first = chunks.next
      assert_equal "PK\x03\x04".b, first.byteslice(0, 4)
      assert_not enumerated
      body = first.dup
      loop { body << chunks.next }
      Zip::File.open_buffer(body) do |zip|
        assert_equal content, zip.read("training_attachments/photo.jpg")
      end
      assert enumerated
      sizes = StreamingAttachmentZip.new([ path ]).each.map(&:bytesize)
      assert_operator sizes.max, :<=, StreamingAttachmentZip::CHUNK_SIZE
    end
  end

  test "duplicate filenames including suffixed names remain unique" do
    Dir.mktmpdir do |directory|
      paths = %w[a/photo.jpg b/photo.jpg c/photo-2.jpg].map do |name|
        path = File.join(directory, name)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, name)
        path
      end
      body = StreamingAttachmentZip.new(paths).each.to_a.join
      Zip::File.open_buffer(body) do |zip|
        names = zip.entries.reject(&:directory?).map(&:name)
        assert_equal 3, names.uniq.size
        assert_equal %w[a/photo.jpg b/photo.jpg c/photo-2.jpg], names.map { |name| zip.read(name) }
      end
    end
  end

  test "empty and missing file exports are valid zip archives" do
    [ [], [ "/nonexistent/training-export-file" ] ].each do |paths|
      Zip::File.open_buffer(StreamingAttachmentZip.new(paths).each.to_a.join) do |zip|
        assert_equal [ StreamingAttachmentZip::DIRECTORY ], zip.entries.map(&:name)
      end
    end
  end
end
