# The FCOs the dashboard works with.
#
# Two different lists live here, and mixing them up is what caused the bugs this
# replaced:
#
#   offices  - the FCO-C offices configured in Office Setup. These get a card in
#              every dashboard box. Today: FCO-C Sausar, FCO-C Turekela,
#              "direact to  ho". Add one in Office Setup and it appears
#              everywhere without a code change.
#   afl_rows - every FCO the farmer master knows (ten of them). Used to resolve
#              an office to its numeric code and name, not to draw boxes.
#
# An office carries its own display name but reports on the data of the sub
# office it is mapped to, so "direact to  ho" shows 1095 Pavijetpur's farmers
# under its own label.
class FcoDirectory
  # Only used when nothing is configured, so a broken lookup cannot blank out
  # every dashboard number.
  FALLBACK = [
    { id: "1004", name: "Sausar" },
    { id: "1006", name: "Turekela" },
    { id: "1095", name: "Pavijetpur" }
  ].freeze

  # Memoised per request. CurrentAttributes resets between requests, so a newly
  # added office is live on the next page load. A shared Rails.cache was wrong
  # here: it outlived the data it described, which made the dashboard answer
  # depend on whatever happened to populate the cache first.
  class Store < ActiveSupport::CurrentAttributes
    attribute :afl_rows, :offices
  end

  # Imported rows carry the string "NULL" where the source file had no value.
  JUNK = %w[null nil none n/a -].freeze

  # AFL stores the office name with or without its prefix ("Sausar", "FCO-C
  # Sausar", "FCO-Pavijetpur"). Cards are labelled "<name> Male", so the prefix
  # has to come off or the dashboard reads "FCO-C Sausar Male" while the mobile
  # API -- which strips it -- reads "Sausar Male".
  PREFIX = /\Afco\s*(?:-\s*c)?\s*[-:]?\s*/i
  # Sub offices are written "TO-Pavijetpur", "TO -Sausar", "TO- Turekela".
  SUB_OFFICE_PREFIX = /\Ato\s*[-: ]\s*/i

  def self.bare_name(value)
    value.to_s.squish.sub(PREFIX, "").squish
  end

  # --- The dashboard list: Office Setup FCO-C offices -----------------------

  # [{ id: "1095", name: "direact to  ho", afl_name: "Pavijetpur" }, ...]
  def self.offices
    Store.offices ||= load_offices
  end

  # Box labels, e.g. ["Sausar", "Turekela", "direact to  ho"].
  def self.names
    offices.filter_map { |office| office[:name].presence }.presence || FALLBACK.map { |row| row[:name] }
  end

  # The numeric office codes behind those labels, e.g. ["1004", "1006", "1095"].
  def self.ids
    offices.filter_map { |office| office[:id].presence }.presence || FALLBACK.map { |row| row[:id] }
  end

  # Every spelling a stored value might use for the configured offices: the
  # office's own name, its "FCO-C" form, and the code and name of the sub office
  # it reports through -- that last part is what lets "direact to  ho" match
  # rows filed under 1095 / Pavijetpur.
  def self.filter_values
    offices.flat_map { |office| aliases_for_office(office) }
      .map { |value| value.to_s.strip }.reject(&:blank?).uniq
  end

  # The spellings equivalent to one filter value. Returns [] for a value that is
  # not a configured office, so callers fall back to their own handling.
  def self.aliases_for(value)
    bare = bare_name(value).downcase
    office = offices.find do |candidate|
      [candidate[:name], candidate[:afl_name], candidate[:id]].compact.any? { |other| bare_name(other).downcase == bare }
    end
    office ? aliases_for_office(office) : []
  end

  def self.aliases_for_office(office)
    [office[:id], office[:name], "FCO-C #{office[:name]}", office[:raw_name],
     office[:afl_name], ("FCO-C #{office[:afl_name]}" if office[:afl_name].present?)]
      .compact_blank.uniq
  end

  # --- The farmer master: every FCO that has data ---------------------------

  def self.afl_rows
    Store.afl_rows ||= load_afl_rows
  end

  # { "1004" => "Sausar", ... } across the whole farmer master.
  def self.name_by_id
    afl_rows.to_h { |row| [row[:id], row[:name].presence || row[:id]] }
  end

  # { "sausar" => "1004", ... }, keyed on the lowercased bare name.
  def self.id_by_name
    afl_rows.each_with_object({}) do |row, map|
      key = row[:name].to_s.downcase
      map[key] ||= row[:id] if key.present?
    end
  end

  def self.name_for(id)
    name_by_id[id.to_s.strip].presence || id.to_s.strip
  end

  def self.id_for(name)
    id_by_name[bare_name(name).downcase]
  end

  def self.reset_cache!
    Store.afl_rows = nil
    Store.offices = nil
  end

  # --- Loading --------------------------------------------------------------

  SOURCES = [
    [:Afl, :fco_id, :fco],
    [:VrpIcsMapping, :fco_id, :fco_name],
    [:TargetMapping, :fco_id, :fco_name]
  ].freeze

  def self.load_afl_rows
    found = SOURCES.flat_map { |model, id_column, name_column| pairs(model, id_column, name_column) }
      .map { |id, name| { id: id.to_s.strip, name: bare_name(name), raw_name: name.to_s.squish } }
      .reject { |row| junk?(row[:id]) || junk?(row[:name]) }
      # An FCO id is a numeric office code. Some target rows put the name in the
      # id column, which produced a second "Sausar" sharing one real office.
      .sort_by { |row| [row[:id].match?(/\A\d+\z/) ? 0 : 1, row[:name].downcase] }
      .uniq { |row| row[:name].downcase }
      .uniq { |row| row[:id].downcase }
      .sort_by { |row| (row[:name].presence || row[:id]).downcase }
    found.presence || FALLBACK.map { |row| row.merge(raw_name: row[:name]) }
  end
  private_class_method :load_afl_rows

  # Office Setup drives the dashboard list. Each FCO-C office is resolved to a
  # numeric code through the sub office it is mapped to; an office that resolves
  # to nothing is still listed, just with no data behind it.
  def self.load_offices
    return fallback_offices unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    records = ModuleRecord.where(module_slug: %w[office-category-add office-mapping-add])
      .filter_map { |record| record.data if record.data.is_a?(Hash) }
    return fallback_offices if records.blank?

    sub_offices = records.each_with_object({}) do |data, map|
      office = bare_name(data["office_name"]).downcase
      sub = bare_name(data["sub_office_name"].to_s.sub(SUB_OFFICE_PREFIX, ""))
      map[office] ||= sub if office.present? && sub.present? && id_by_name.key?(sub.downcase)
    end

    found = records.select { |data| fco_office?(data) }
      .filter_map { |data| build_office(data, sub_offices) }
      .uniq { |office| office[:name].downcase }
      .sort_by { |office| office[:name].downcase }
    found.presence || fallback_offices
  rescue StandardError => e
    Rails.logger.warn("FcoDirectory office lookup failed: #{e.class} - #{e.message}")
    fallback_offices
  end
  private_class_method :load_offices

  def self.fco_office?(data)
    bare_name(data["parent_category"]).casecmp("c").zero? ||
      data["parent_category"].to_s.squish.casecmp("FCO-C").zero?
  end
  private_class_method :fco_office?

  def self.build_office(data, sub_offices)
    raw = data["office_name"].to_s.squish
    name = bare_name(raw)
    return nil if junk?(name)

    # An office named after a real FCO resolves to itself; otherwise it reports
    # through whichever sub office it was mapped to.
    afl_name = id_by_name.key?(name.downcase) ? name : sub_offices[name.downcase]
    { id: afl_name.present? ? id_for(afl_name).to_s : "", name: name, raw_name: raw, afl_name: afl_name }
  end
  private_class_method :build_office

  def self.fallback_offices
    rows = afl_rows.presence || FALLBACK
    scoped = rows.select { |row| FALLBACK.any? { |known| known[:id] == row[:id] } }.presence || rows
    scoped.map { |row| { id: row[:id], name: row[:name], raw_name: row[:name], afl_name: row[:name] } }
  end
  private_class_method :fallback_offices

  # One bad source must not blank out the whole dashboard, so each is isolated.
  def self.pairs(model_name, id_column, name_column)
    return [] unless Object.const_defined?(model_name)

    model = Object.const_get(model_name)
    return [] unless model.table_exists?

    model.where.not(id_column => [nil, ""]).distinct.pluck(id_column, name_column)
  rescue StandardError => e
    Rails.logger.warn("FcoDirectory #{model_name} lookup failed: #{e.class} - #{e.message}")
    []
  end
  private_class_method :pairs

  def self.junk?(value)
    text = value.to_s.strip
    text.blank? || JUNK.include?(text.downcase)
  end
  private_class_method :junk?
end
