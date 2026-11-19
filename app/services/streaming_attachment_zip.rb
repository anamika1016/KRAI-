require "zlib"
require "set"

# ZIP64 entries with data descriptors allow non-seekable HTTP output.
# Photos/PDFs are stored; worksheet XML uses fast streaming compression.
class StreamingAttachmentZip
  CHUNK_SIZE = 64 * 1024
  DIRECTORY = "training_attachments/".freeze

  def initialize(paths = [], entries: nil, compress: false, zip64: true)
    @paths = paths
    @entries = entries
    @compress = compress
    @zip64 = zip64
  end

  def each
    return enum_for(:each) unless block_given?

    offset = 0
    entries = []
    names = Set.new
    emit = ->(bytes) { offset += bytes.bytesize; yield bytes }
    write_entry = lambda do |name, chunks|
      name = name.encode(Encoding::UTF_8).b
      start = offset
      # UTF-8 names, trailing CRC/sizes, ZIP64 size placeholders.
      method = @compress ? 8 : 0
      version = @zip64 ? 45 : 20
      extra = @zip64 ? [ 1, 16, 0, 0 ].pack("vvQ<Q<") : "".b
      placeholder = @zip64 ? 0xffffffff : 0
      emit.call([ 0x04034b50, version, 0x0808, method, 0, 33, 0, placeholder, placeholder,
        name.bytesize, extra.bytesize ].pack("VvvvvvVVVvv") + name + extra)
      crc = 0
      size = 0
      compressed_size = 0
      compressor = Zlib::Deflate.new(Zlib::BEST_SPEED, -Zlib::MAX_WBITS) if @compress
      chunks&.each do |chunk|
        chunk = chunk.b
        crc = Zlib.crc32(chunk, crc)
        size += chunk.bytesize
        bytes = compressor ? compressor.deflate(chunk, Zlib::SYNC_FLUSH) : chunk
        compressed_size += bytes.bytesize
        emit.call(bytes) unless bytes.empty?
      end
      if compressor
        bytes = compressor.finish
        compressed_size += bytes.bytesize
        emit.call(bytes)
      end
      check_zip32_limits!(size, compressed_size, offset) unless @zip64
      descriptor_format = @zip64 ? "VVQ<Q<" : "VVVV"
      emit.call([ 0x08074b50, crc, compressed_size, size ].pack(descriptor_format))
      entries << [ name, crc, size, compressed_size, start, method ]
    ensure
      compressor&.close
    end

    # Start the response before enumerating records or opening attachments.
    if @entries
      @entries.each { |name, chunks| write_entry.call(name, chunks) }
    else
      write_attachment_entries(write_entry, names)
    end

    directory_offset = offset
    entries.each do |name, crc, size, compressed_size, start, method|
      extra = @zip64 ? [ 1, 24, size, compressed_size, start ].pack("vvQ<Q<Q<") : "".b
      version = @zip64 ? 45 : 20
      emit.call([ 0x02014b50, version, version, 0x0808, method, 0, 33, crc,
        @zip64 ? 0xffffffff : compressed_size, @zip64 ? 0xffffffff : size,
        name.bytesize, extra.bytesize, 0, 0, 0, 0, @zip64 ? 0xffffffff : start ].pack("VvvvvvvVVVvvvvvVV") + name + extra)
    end
    directory_size = offset - directory_offset
    if @zip64
      zip64_offset = offset
      emit.call([ 0x06064b50, 44, 45, 45, 0, 0, entries.size, entries.size,
        directory_size, directory_offset ].pack("VQ<vvVVQ<Q<Q<Q<"))
      emit.call([ 0x07064b50, 0, zip64_offset, 1 ].pack("VVQ<V"))
      emit.call([ 0x06054b50, 0, 0, 0xffff, 0xffff, 0xffffffff, 0xffffffff, 0 ].pack("VvvvvVVv"))
    else
      check_zip32_limits!(directory_size, directory_offset)
      raise RangeError, "Too many ZIP entries" if entries.size >= 0xffff

      emit.call([ 0x06054b50, 0, 0, entries.size, entries.size, directory_size, directory_offset, 0 ].pack("VvvvvVVv"))
    end
  end

  private

  def check_zip32_limits!(*values)
    raise RangeError, "Excel ZIP entry exceeds the 4 GiB compatibility limit" if values.any? { |value| value >= 0xffffffff }
  end

  def write_attachment_entries(write_entry, names)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    file_count = 0
    total_bytes = 0
    next_suffix = Hash.new(2)
    write_entry.call(DIRECTORY, nil)
    @paths.each do |path|
      base = File.basename(path.to_s)
      name = base
      suffix = next_suffix[base]
      while names.include?(name)
        extension = File.extname(base)
        name = "#{File.basename(base, extension)}-#{suffix}#{extension}"
        suffix += 1
      end
      next_suffix[base] = suffix
      begin
        File.open(path, "rb") do |io|
          if file_count.zero?
            elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
            Rails.logger.info("training_attachment_zip first_file_ms=#{elapsed_ms}")
          end
          names.add(name)
          chunks = Enumerator.new do |output|
            while (chunk = io.read(CHUNK_SIZE))
              output << chunk
            end
          end
          write_entry.call("#{DIRECTORY}#{name}", chunks)
          file_count += 1
          total_bytes += io.pos
        end
      rescue Errno::ENOENT, Errno::EACCES => error
        Rails.logger.warn("Training attachment unavailable: #{error.class}")
      end
    end
    completed = true
  ensure
    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    Rails.logger.info("training_attachment_zip completed=#{completed == true} files=#{file_count} source_bytes=#{total_bytes} elapsed_ms=#{elapsed_ms}")
  end
end
