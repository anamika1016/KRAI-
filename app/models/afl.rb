require "csv"
require "date"
require "bigdecimal"
require "nokogiri"
require "zip"

class Afl < ApplicationRecord
  IMPORT_BATCH_SIZE = 2_000

  IMPORT_COLUMNS = %i[
    farm_id fco_id fco fpo_id fpo_name ics_id ics_name village_id village_name ginning_id broker_id farmer_name father_name
    tracenet_no total_farm_area purchase_quantity_amount estimate_quantity purchase_quantity
    purchase_date dispoce ip date estimate_quantity_admin slip_no mobile_no purchase_product
    purchase_product_type khasara_no longitude lattitude aadhar reg_type fy qr_aadhar
    qr_mobile qrcode qrcode_date status
  ].freeze

  LIST_COLUMNS = %i[
    id farm_id fco_id fco fpo_id fpo_name ics_id ics_name village_id village_name farmer_name father_name tracenet_no total_farm_area
    purchase_quantity_amount estimate_quantity purchase_quantity purchase_date mobile_no purchase_product
    status created_at
  ].freeze

  DECIMAL_COLUMNS = %i[
    total_farm_area purchase_quantity_amount estimate_quantity purchase_quantity
    estimate_quantity_admin longitude lattitude
  ].freeze

  DATE_COLUMNS = %i[purchase_date date].freeze
  DATETIME_COLUMNS = %i[qrcode_date].freeze

  HEADER_ALIASES = {
    "Farm_ID" => :farm_id,
    "FCO_ID" => :fco_id,
    "FCO" => :fco,
    "FPO_ID" => :fpo_id,
    "FPO_Name" => :fpo_name,
    "ICS_ID" => :ics_id,
    "ICS_NAME" => :ics_name,
    "Village_ID" => :village_id,
    "Village_Name" => :village_name,
    "Ginning_Id" => :ginning_id,
    "Broker_Id" => :broker_id,
    "Farmer_Name" => :farmer_name,
    "Father_Name" => :father_name,
    "Tracenet_No" => :tracenet_no,
    "Total_Farm_Area" => :total_farm_area,
    "Purchase_Quantity_Amount" => :purchase_quantity_amount,
    "Estimate_Quantity" => :estimate_quantity,
    "Purchase_Quantity" => :purchase_quantity,
    "Purchase_Date" => :purchase_date,
    "Dispoce" => :dispoce,
    "IP" => :ip,
    "Date" => :date,
    "Estimate_Quantity_Admin" => :estimate_quantity_admin,
    "Slip_No" => :slip_no,
    "Mobile_No" => :mobile_no,
    "Purchase_Product" => :purchase_product,
    "Purchase_Product_Type" => :purchase_product_type,
    "Khasara_NO" => :khasara_no,
    "Longitude" => :longitude,
    "Lattitude" => :lattitude,
    "AAdhar" => :aadhar,
    "reg_type" => :reg_type,
    "FY" => :fy,
    "QR_AADHAR" => :qr_aadhar,
    "QR_MOBILE" => :qr_mobile,
    "QRCODE" => :qrcode,
    "QRCODE_DATE" => :qrcode_date,
    "Status" => :status
  }.freeze

  validates :farmer_name, presence: true

  def self.import(file)
    raise ArgumentError, "Please choose an Excel or CSV file." unless file.present?

    extension = File.extname(file.original_filename.to_s).downcase
    return import_csv(file.path) if extension == ".csv"

    rows = rows_from_upload(file)
    headers = rows.shift
    raise ArgumentError, "Uploaded file is blank." if headers.blank?

    import_rows(rows, headers)
  end

  def self.import_rows(rows, headers)
    attributes_by_index = headers.map { |header| column_for_header(header) }
    imported = 0
    skipped = []
    batch = []

    rows.each_with_index do |row, index|
      queue_import_row(row, index + 2, attributes_by_index, batch, skipped)
      imported += flush_import_batch(batch, skipped) if batch.size >= IMPORT_BATCH_SIZE
    end

    imported += flush_import_batch(batch, skipped)
    { imported: imported, skipped: skipped }
  end

  def self.import_csv(path)
    csv = CSV.new(csv_text_from(path), headers: false)
    headers = csv.shift
    raise ArgumentError, "Uploaded file is blank." if headers.blank?

    attributes_by_index = headers.map { |header| column_for_header(header) }
    imported = 0
    skipped = []
    batch = []

    csv.each.with_index(2) do |row, row_number|
      queue_import_row(row, row_number, attributes_by_index, batch, skipped)
      imported += flush_import_batch(batch, skipped) if batch.size >= IMPORT_BATCH_SIZE
    end

    imported += flush_import_batch(batch, skipped)
    { imported: imported, skipped: skipped }
  ensure
    csv&.close
  end

  # Excel's "CSV (Comma delimited)" export writes the system's ANSI codepage
  # (Windows-1252), not UTF-8, so handing the raw file straight to CSV.open
  # raised CSV::InvalidEncodingError on the first accented/special byte. Every
  # byte has a Windows-1252 mapping, so re-reading through it never raises --
  # a genuinely UTF-8 file (the common case) passes through on the first try.
  def self.csv_text_from(path)
    text = File.read(path, encoding: "bom|utf-8")
    return text if text.valid_encoding?

    File.read(path, encoding: "Windows-1252:UTF-8", invalid: :replace, undef: :replace)
  end

  def self.queue_import_row(row, row_number, attributes_by_index, batch, skipped)
    attrs = attributes_from_row(row, attributes_by_index)
    return if attrs.values.all?(&:blank?)

    timestamp = Time.current
    batch << [row_number, attrs.merge(created_at: timestamp, updated_at: timestamp)]
  end

  def self.flush_import_batch(batch, skipped)
    return 0 if batch.blank?

    rows = batch.map(&:last)
    insert_all(rows)
    rows.size
  rescue ActiveRecord::RangeError, ActiveRecord::StatementInvalid => e
    insert_batch_one_by_one(batch, skipped)
  ensure
    batch.clear
  end

  def self.insert_batch_one_by_one(batch, skipped)
    imported = 0

    batch.each do |row_number, attrs|
      insert_all([attrs])
      imported += 1
    rescue ActiveRecord::RangeError, ActiveRecord::StatementInvalid => e
      skipped << skipped_row(row_number, e.message.to_s.split("\n").first, attrs)
    end

    imported
  end

  def self.column_for_header(header)
    raw_header = header.to_s.strip
    HEADER_ALIASES[raw_header] || IMPORT_COLUMNS.find { |column| normalized_header(column) == normalized_header(raw_header) }
  end

  def self.searchable_columns
    column_names.map(&:to_sym) - %i[id created_at updated_at]
  end

  def self.search(query)
    query = query.to_s.strip
    return all if query.blank?

    adapter = connection.adapter_name.to_s.downcase
    cast_type = adapter.include?("mysql") ? "CHAR" : "TEXT"

    clauses = searchable_columns.map do |column|
      quoted_column = connection.quote_column_name(column)
      casted_column = "CAST(#{quoted_column} AS #{cast_type})"

      if adapter.include?("postgres")
        "#{casted_column} ILIKE :query"
      else
        "LOWER(#{casted_column}) LIKE :query"
      end
    end

    pattern = if adapter.include?("postgres")
      "%#{sanitize_sql_like(query)}%"
    else
      "%#{sanitize_sql_like(query.downcase)}%"
    end

    where(clauses.join(" OR "), query: pattern)
  end

  # The same four choices the heading filter offers on every other list.
  COLUMN_FILTER_OPERATORS = %w[contains equals starts ends].freeze

  # Per-heading search: every filled-in heading box narrows the list further,
  # so "FCO Name = sausar" plus "ICS Name = bastrani" means both, not either.
  # Only real columns are honoured, so an unknown key in the query string can
  # never reach SQL -- and a new column becomes filterable with no change here.
  def self.column_filtered(filters, operators = {})
    allowed = searchable_columns.map(&:to_s)
    adapter = connection.adapter_name.to_s.downcase
    cast_type = adapter.include?("mysql") ? "CHAR" : "TEXT"
    chosen = column_filter_values(operators)

    column_filter_values(filters).reduce(all) do |scope, (column, term)|
      next scope unless allowed.include?(column)

      casted = "CAST(#{connection.quote_column_name(column)} AS #{cast_type})"
      pattern = column_filter_pattern(term, chosen[column])
      if adapter.include?("postgres")
        scope.where("#{casted} ILIKE :term", term: pattern)
      else
        scope.where("LOWER(#{casted}) LIKE :term", term: pattern.downcase)
      end
    end
  end

  def self.column_filter_pattern(term, operator)
    escaped = sanitize_sql_like(term)
    case operator
    when "equals" then escaped
    when "starts" then "#{escaped}%"
    when "ends"   then "%#{escaped}"
    else "%#{escaped}%"
    end
  end
  private_class_method :column_filter_pattern

  def self.column_filter_values(filters)
    return {} unless filters.respond_to?(:to_unsafe_h) || filters.is_a?(Hash)

    hash = filters.respond_to?(:to_unsafe_h) ? filters.to_unsafe_h : filters
    hash.to_h { |column, term| [column.to_s, term.to_s.strip] }.reject { |_, term| term.blank? }
  end

  def self.normalized_coordinate(value)
    return if value.blank?

    BigDecimal(value.to_s).round(8).to_s("F")
  rescue ArgumentError
    nil
  end

  def self.skipped_row(row_number, reason, attrs = {})
    {
      row: row_number,
      reason: reason,
      farm_id: attrs[:farm_id],
      tracenet_no: attrs[:tracenet_no],
      longitude: attrs[:longitude],
      lattitude: attrs[:lattitude],
      khasara_no: attrs[:khasara_no],
      farmer_name: attrs[:farmer_name],
      father_name: attrs[:father_name],
      village_id: attrs[:village_id],
      village_name: attrs[:village_name]
    }
  end

  def self.attributes_from_row(row, attributes_by_index)
    attributes_by_index.each_with_index.each_with_object({}) do |(column, index), attrs|
      next unless column

      attrs[column] = cast_import_value(column, row[index])
    end
  end

  def self.cast_import_value(column, value)
    value = value.to_s.strip if value.is_a?(String)
    return if value.blank?

    return parse_decimal(value) if DECIMAL_COLUMNS.include?(column)
    return parse_date(value) if DATE_COLUMNS.include?(column)
    return parse_datetime(value) if DATETIME_COLUMNS.include?(column)

    value
  end

  def self.parse_decimal(value)
    BigDecimal(value.to_s.delete(","))
  rescue ArgumentError
    nil
  end

  def self.parse_date(value)
    return value.to_date if value.respond_to?(:to_date)
    return excel_serial_date(value) if value.to_s.match?(/\A\d+(\.\d+)?\z/)

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def self.parse_datetime(value)
    return value.to_datetime if value.respond_to?(:to_datetime)
    return excel_serial_date(value).to_datetime if value.to_s.match?(/\A\d+(\.\d+)?\z/)

    DateTime.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def self.excel_serial_date(value)
    Date.new(1899, 12, 30) + value.to_f
  end

  def self.rows_from_upload(file)
    extension = File.extname(file.original_filename.to_s).downcase

    case extension
    when ".xlsx"
      rows_from_xlsx(file.path)
    else
      raise ArgumentError, "Only .xlsx and .csv files are supported."
    end
  end

  def self.rows_from_xlsx(path)
    Zip::File.open(path) do |zip|
      shared_strings = xlsx_shared_strings(zip)
      sheet_entry = zip.find_entry("xl/worksheets/sheet1.xml")
      raise ArgumentError, "Could not find first sheet in the Excel file." unless sheet_entry

      handler = XlsxRowHandler.new(shared_strings)
      Nokogiri::XML::SAX::Parser.new(handler).parse(sheet_entry.get_input_stream.read)
      handler.rows
    end
  end

  def self.xlsx_shared_strings(zip)
    entry = zip.find_entry("xl/sharedStrings.xml")
    return [] unless entry

    document = Nokogiri::XML(entry.get_input_stream.read)
    document.remove_namespaces!
    document.xpath("//si").map { |item| item.xpath(".//t").map(&:text).join }
  end

  # Streams xl/worksheets/sheet1.xml instead of building a DOM. REXML's XPath
  # re-scans the whole tree for every row and every cell lookup inside it, so
  # it had no trouble with a handful of rows but a 1,000-row AFL file alone
  # took 28s to parse -- for a real import of tens of thousands of rows that
  # was minutes before the database work even started, well past the proxy's
  # timeout. A cell is either a shared string (t="s", looked up by index into
  # xlsx_shared_strings) or an inline value/string -- both arrive as the text
  # inside <v> or <is><t>, so one small buffer covers both.
  class XlsxRowHandler < Nokogiri::XML::SAX::Document
    attr_reader :rows

    def initialize(shared_strings)
      super()
      @shared_strings = shared_strings
      @rows = []
    end

    def start_element(name, attrs = [])
      case name
      when "row"
        @row = []
      when "c"
        attributes = attrs.to_h
        @cell_index = Afl.xlsx_column_index(attributes["r"])
        @cell_shared = attributes["t"] == "s"
        @cell_value = nil
      when "v", "t"
        @buffer = +""
      end
    end

    def characters(string)
      @buffer << string if @buffer
    end

    def end_element(name)
      case name
      when "v", "t"
        @cell_value = @buffer if @buffer.present?
        @buffer = nil
      when "c"
        @row[@cell_index] = @cell_shared ? @shared_strings[@cell_value.to_i] : @cell_value if @cell_index
      when "row"
        @rows << @row
        @row = nil
      end
    end
  end

  def self.xlsx_column_index(reference)
    letters = reference.to_s[/[A-Z]+/]
    return 0 if letters.blank?

    letters.chars.reduce(0) { |sum, char| (sum * 26) + char.ord - 64 } - 1
  end

  def self.normalized_header(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
  end
end
