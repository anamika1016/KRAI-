require "csv"
require "rexml/document"
require "zip"

class LgDirectoryImporter
  HEADER_ALIASES = {
    "state" => :state,
    "stateentry" => :state,
    "statename" => :state,
    "district" => :district,
    "districtentry" => :district,
    "districtname" => :district,
    "block" => :block,
    "blockentry" => :block,
    "blockname" => :block,
    "gp" => :gram_panchayat,
    "gpentry" => :gram_panchayat,
    "gram panchayat" => :gram_panchayat,
    "grampanchayat" => :gram_panchayat,
    "grampanchayatname" => :gram_panchayat,
    "village" => :village,
    "villageentry" => :village,
    "villagename" => :village,
    "status" => :status
  }.freeze

  MODULE_DEFINITIONS = [
    {
      slug: "state-master",
      key: :state,
      fields: {
        "state_name" => :state,
        "status" => :status
      }
    },
    {
      slug: "district-master",
      key: :district,
      fields: {
        "state" => :state,
        "district_name" => :district,
        "status" => :status
      }
    },
    {
      slug: "block-master",
      key: :block,
      fields: {
        "state" => :state,
        "district" => :district,
        "block_name" => :block,
        "status" => :status
      }
    },
    {
      slug: "gram-panchayat-master",
      key: :gram_panchayat,
      fields: {
        "state" => :state,
        "district" => :district,
        "block" => :block,
        "gram_panchayat_name" => :gram_panchayat,
        "status" => :status
      }
    },
    {
      slug: "village-master",
      key: :village,
      fields: {
        "state" => :state,
        "district" => :district,
        "block" => :block,
        "gram_panchayat" => :gram_panchayat,
        "village_name" => :village,
        "status" => :status
      }
    }
  ].freeze

  def self.import(file)
    raise ArgumentError, "Please choose an Excel or CSV file." unless file.present?

    rows = rows_from_upload(file)
    headers = rows.shift
    raise ArgumentError, "Uploaded file is blank." if headers.blank?

    import_rows(rows, headers)
  end

  def self.import_rows(rows, headers)
    attributes_by_index = headers.map { |header| column_for_header(header) }
    raise ArgumentError, "Excel headers should include State, District, Block, GP, Village, and Status." if attributes_by_index.compact.blank?

    created_counts = Hash.new(0)
    skipped = []
    existing_records = existing_records_by_key

    ModuleRecord.transaction do
      rows.each_with_index do |row, index|
        attrs = attributes_from_row(row, attributes_by_index)
        next if attrs.values.all?(&:blank?)

        attrs[:status] = normalized_status(attrs[:status])
        created_for_row = create_hierarchy_records(attrs, existing_records, created_counts)
        skipped << skipped_row(index + 2, "No LG Directory value found.") if created_for_row.zero?
      end
    end

    {
      imported: created_counts.values.sum,
      counts: created_counts,
      skipped: skipped
    }
  end

  def self.create_hierarchy_records(attrs, existing_records, created_counts)
    created = 0

    MODULE_DEFINITIONS.each do |definition|
      next if attrs[definition[:key]].blank?

      data = definition[:fields].transform_values { |source_key| attrs[source_key].to_s.strip }
      fingerprint = record_fingerprint(definition[:slug], data)
      if (record = existing_records[fingerprint])
        record.update!(data: record.data.merge("status" => data["status"]))
        next
      end

      record = ModuleRecord.create!(module_slug: definition[:slug], data: data)
      existing_records[fingerprint] = record
      created_counts[definition[:slug]] += 1
      created += 1
    end

    created
  end

  def self.rows_from_upload(file)
    extension = File.extname(file.original_filename.to_s).downcase

    case extension
    when ".csv"
      CSV.read(file.path, headers: false)
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

      sheet = REXML::Document.new(sheet_entry.get_input_stream.read)
      REXML::XPath.match(sheet, "//*[local-name()='row']").map do |row|
        cells = []
        REXML::XPath.match(row, "*[local-name()='c']").each do |cell|
          index = xlsx_column_index(cell.attributes["r"])
          cells[index] = xlsx_cell_value(cell, shared_strings)
        end
        cells
      end
    end
  end

  def self.xlsx_shared_strings(zip)
    entry = zip.find_entry("xl/sharedStrings.xml")
    return [] unless entry

    document = REXML::Document.new(entry.get_input_stream.read)
    REXML::XPath.match(document, "//*[local-name()='si']").map do |item|
      REXML::XPath.match(item, ".//*[local-name()='t']").map(&:text).join
    end
  end

  def self.xlsx_cell_value(cell, shared_strings)
    value = REXML::XPath.first(cell, "*[local-name()='v']")&.text
    inline = REXML::XPath.match(cell, "*[local-name()='is']//*[local-name()='t']").map(&:text).join
    return inline if inline.present?
    return if value.blank?

    cell.attributes["t"] == "s" ? shared_strings[value.to_i] : value
  end

  def self.xlsx_column_index(reference)
    letters = reference.to_s[/[A-Z]+/]
    return 0 if letters.blank?

    letters.chars.reduce(0) { |sum, char| (sum * 26) + char.ord - 64 } - 1
  end

  def self.attributes_from_row(row, attributes_by_index)
    attributes_by_index.each_with_index.each_with_object({}) do |(column, index), attrs|
      next unless column

      attrs[column] = row[index].to_s.strip
    end
  end

  def self.column_for_header(header)
    HEADER_ALIASES[normalized_header(header)]
  end

  def self.existing_records_by_key
    {}.tap do |records_by_key|
      MODULE_DEFINITIONS.each do |definition|
        ModuleRecord.where(module_slug: definition[:slug]).find_each do |record|
          records_by_key[record_fingerprint(definition[:slug], record.data)] ||= record
        end
      end
    end
  end

  def self.record_fingerprint(slug, data)
    values = MODULE_DEFINITIONS
      .find { |definition| definition[:slug] == slug }
      .fetch(:fields)
      .keys
      .reject { |key| key == "status" }
      .map { |key| data[key].to_s.strip.downcase }

    ([slug] + values).join("|")
  end

  def self.normalized_header(value)
    value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "")
  end

  def self.normalized_status(value)
    status = value.to_s.strip
    return "Inactive" if ["inactive", "deactive", "disabled"].include?(status.downcase)

    "Active"
  end

  def self.skipped_row(row_number, reason)
    { row: row_number, reason: reason }
  end
end
