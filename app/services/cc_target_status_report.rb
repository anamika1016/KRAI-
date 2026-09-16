class CcTargetStatusReport
  FCO_IDS = %w[1004 1006].freeze
  HEADERS = ["month", "fco_id", "fpo_name", "cluster_incharge", "jj_names", "target", "achievement", "status"].freeze

  def initialize(calculator:, month: nil, fco: nil)
    @calculator = calculator
    filters = calculator.respond_to?(:params) && calculator.request ? calculator.params : {}
    @month = (month || (filters.key?(:month) ? filters[:month] : Date.current.prev_month.strftime("%B"))).to_s.strip
    @fco = (fco || filters[:fcoc] || filters[:fco] || filters[:fco_id]).to_s.strip
    @fco = "" if @fco.downcase.start_with?("all")
    @fco = "1004" if @fco.downcase.include?("sausar")
    @fco = "1006" if @fco.downcase.include?("turekela")
  end

  def summary
    @summary ||= calculate_summary
  end

  def rows
    @rows ||= calculate_rows
  end

  def caption
    "#{all_months? ? 'All Months' : @month} · #{{ '1004' => 'Sausar', '1006' => 'Turekela' }.fetch(@fco, 'Sausar and Turekela')}"
  end

  private

  def all_months?
    @month.blank? || @month.downcase.start_with?("all")
  end

  def calculate_rows
    target_data     = fetch_cc_targets
    achievement_data = fetch_cc_achievements
    jj_data         = fetch_cc_jj_names

    # Only show CCs that have been given a cc_target > 0
    results = target_data.keys.map do |key|
      fco_id, cc_name = key
      target      = target_data[key].to_i
      achievement = achievement_data[key].to_i
      jj_names    = jj_data[key] || []

      status = if target.positive? && achievement.zero?
        "Red"
      elsif target.positive? && achievement > 0 && achievement < target
        "Yellow"
      else
        "Green"
      end

      fpo_name = case fco_id
      when "1004" then "Sausar"
      when "1006" then "Turekela"
      else fco_id
      end

      {
        "month"           => all_months? ? "All Months" : @month,
        "fco_id"          => fco_id,
        "fpo_name"        => fpo_name,
        "cluster_incharge" => cc_name,
        "jj_names"        => jj_names,
        "target"          => target,
        "achievement"     => achievement,
        "status"          => status
      }
    end

    selected_fcos = @fco.blank? ? FCO_IDS : FCO_IDS & [@fco]
    results.select { |row| selected_fcos.include?(row["fco_id"]) }
      .sort_by { |row| [row["fco_id"].to_s, row["cluster_incharge"].to_s] }
  end

  def calculate_summary
    detailed_rows = rows
    by_fco_and_status = detailed_rows.group_by { |r| [r["fco_id"], r["status"]] }

    selected_fcos = @fco.blank? ? FCO_IDS : FCO_IDS & [@fco]
    summary_results = []

    selected_fcos.each do |fco_id|
      %w[Red Yellow Green].each do |status|
        cc_rows = by_fco_and_status[[fco_id, status]] || []
        summary_results << {
          "month"            => all_months? ? "All Months" : @month,
          "fco_id"           => fco_id,
          "status"           => status,
          "cc_count"         => cc_rows.size,
          "total_target"     => cc_rows.sum { |r| r["target"] },
          "total_achievement" => cc_rows.sum { |r| r["achievement"] }
        }
      end
    end

    summary_results
  end

  def fetch_cc_targets
    targets = {}
    return targets unless ActiveRecord::Base.connection.table_exists?("target_mappings")

    target_scope = TargetMapping.joins("LEFT JOIN vrps ON target_mappings.vrp_id = vrps.id")
    unless all_months?
      target_scope = target_scope.where("LOWER(TRIM(target_mappings.month_name)) = ?", @month.downcase)
    end

    target_scope.pluck(
      "target_mappings.id",
      "target_mappings.cc_target",
      "target_mappings.fco_id",
      "target_mappings.fco_name",
      "vrps.fcoc",
      "vrps.cluster_incharge"
    ).each do |_id, cc_target, fco_id_raw, fco_name_raw, fcoc_raw, cluster_incharge|
      cc_val = cc_target.to_i
      next if cc_val <= 0

      fco_id  = normalize_fco_id(fco_id_raw, fco_name_raw, fcoc_raw)
      cc_name = cluster_incharge.to_s.strip
      next if cc_name.blank?

      key = [fco_id, cc_name]
      targets[key] = (targets[key] || 0) + cc_val
    end

    targets
  end

  # Count unique training records (achievements) per [fco_id, cc_name].
  # Only counts achievements where the CC has a target (matched via target_data keys).
  def fetch_cc_achievements
    achievements = {}
    return achievements unless ActiveRecord::Base.connection.table_exists?("module_records")

    valid_jj_cc_map = {}
    if ActiveRecord::Base.connection.table_exists?("target_mappings")
      scope = TargetMapping.joins("LEFT JOIN vrps ON target_mappings.vrp_id = vrps.id")
        .where("target_mappings.cc_target > 0")
      scope = scope.where("LOWER(TRIM(target_mappings.month_name)) = ?", @month.downcase) unless all_months?

      scope.pluck(
        "vrps.name",
        "target_mappings.fco_id",
        "target_mappings.fco_name",
        "vrps.fcoc",
        "vrps.cluster_incharge"
      ).each do |vrp_name, fco_id_raw, fco_name_raw, fcoc_raw, cluster_incharge|
        fco_id = normalize_fco_id(fco_id_raw, fco_name_raw, fcoc_raw)
        cc_name = cluster_incharge.to_s.strip
        next if cc_name.blank?

        valid_jj_cc_map[vrp_name.to_s.strip.downcase] = [fco_id, cc_name]
      end
    end

    records = ModuleRecord.where(module_slug: "training-form")
    records.find_each do |rec|
      data = rec.data || {}
      rec_month = data["month"].to_s.strip
      next if !all_months? && rec_month.downcase != @month.downcase

      cc_name = data["cluster_coordinator_name"].to_s.strip.presence || data["cluster_incharge"].to_s.strip.presence
      fco_id = normalize_fco_id(data["ics_block"], data["fco_name"], data["fcoc"])

      key = if cc_name.present?
        [fco_id, cc_name]
      else
        jj_name = data["jeevika_jankar_name"].to_s.strip.downcase
        valid_jj_cc_map[jj_name]
      end

      next if key.blank?

      achievements[key] = (achievements[key] || 0) + 1
    end

    achievements
  end

  # Fetch JJ names grouped per [fco_id, cc_name] from target_mappings
  def fetch_cc_jj_names
    jj_names = {}
    return jj_names unless ActiveRecord::Base.connection.table_exists?("target_mappings")

    scope = TargetMapping.joins("LEFT JOIN vrps ON target_mappings.vrp_id = vrps.id")
      .where("target_mappings.cc_target > 0")
    unless all_months?
      scope = scope.where("LOWER(TRIM(target_mappings.month_name)) = ?", @month.downcase)
    end

    scope.pluck(
      "vrps.name",
      "target_mappings.fco_id",
      "target_mappings.fco_name",
      "vrps.fcoc",
      "vrps.cluster_incharge"
    ).each do |vrp_name, fco_id_raw, fco_name_raw, fcoc_raw, cluster_incharge|
      fco_id  = normalize_fco_id(fco_id_raw, fco_name_raw, fcoc_raw)
      cc_name = cluster_incharge.to_s.strip
      next if cc_name.blank?

      key = [fco_id, cc_name]
      jj_names[key] ||= []
      jj_names[key] << vrp_name.to_s.strip if vrp_name.present?
      jj_names[key].uniq!
    end

    jj_names
  end

  def normalize_fco_id(*vals)
    combined = vals.compact.map(&:to_s).join(" ").strip.downcase
    return "1004" if combined.include?("sausar") || combined.include?("1004")
    return "1006" if combined.include?("turekela") || combined.include?("1006")

    "1004"
  end
end
