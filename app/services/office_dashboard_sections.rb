# Mobile presentation contract. Values come from the web calculators; URLs
# deliberately point to authenticated JSON lists instead of HTML pages.
class OfficeDashboardSections
  ROOT = "/api/v1/user-dashboard".freeze
  SUMMARY = {
    "Total ICS Count" => "summary_ics", "Total Villages Count" => "summary_villages",
    "Total Farmer Count" => "summary_farmers",
    "Total Mapped Main Activities" => "total_mapped_main_activities",
    "Total Mapped Sub-Activities" => "total_mapped_sub_activities"
  }.freeze
  DEMO = %w[opg_training_target general_training_meeting input_demo_inm input_demo_pm ffs_exposure cc_target_status].freeze
  OTHER = {
    main_major_work_indicator: "Main Major Work Indicator", mapped_farmer: "Mapped Farmer",
    achievement_farmer: "Achievement Farmer", pending_farmer: "Pending Farmer", achieved: "Achieved"
  }.freeze

  def initialize(calculator:, targets:, participation:, month:, fcoc:)
    @calculator, @targets, @participation, @month, @fcoc = calculator, targets, participation, month, fcoc
  end

  def sections(only: nil)
    summary = call(:dashboard_summary_cards, @targets).map do |item|
      card(SUMMARY.fetch(item[:title]), item[:title], item[:value], SUMMARY.fetch(item[:title]), popup_items: item[:popup_items])
    end
    demo = demonstration_cards
    participation = [card("mapped_farmer", "Mapped Farmer", call(:training_mapped_farmer_distinct_count_for_participation,
      month_name: @month, fcoc_name: @fcoc, targets: call(:training_participation_targets_for_dashboard, month_name: @month, fcoc_name: @fcoc)), "training_unique_farmers")]
    %w[red yellow green].zip(["Pending", "Only 1 Training", "1+ Trainings"]).each do |status, title|
      participation << card("training_#{status}", title, @participation[status.to_sym].to_i, "training_#{status}")
    end
    primary = [section("summary", "Dashboard Summary", summary),
      section("participation", "Farmer Training Participation Status", participation),
      section("demonstration", "Demonstration Method", demo)]
    return primary if only == :primary

    other = other_totals
    groups = call(:dashboard_cards).filter_map do |group|
      next unless ["FCO-wise JJ Requirement", "Jeevika Jankar Billing", "Gender Count"].include?(group[:title])
      key = { "FCO-wise JJ Requirement" => "fco_requirement", "Jeevika Jankar Billing" => "billing", "Gender Count" => "gender" }.fetch(group[:title])
      items = group[:items].filter_map do |item|
        if key != "billing"
          fco = item[:title].split.first
          next unless Array(@calculator.instance_variable_get(:@filtered_vrps)).any? { |vrp| call(:training_fcoc_text_matches?, vrp.fcoc, fco) }
        end
        item_key = item[:title].downcase.tr(" ", "_")
        list = key == "billing" ? "bill_#{item_key}" : "#{key}_#{item_key}"
        card(list, item[:title], item[:value], list)
      end
      section(key, group[:title], items)
    end
    [section("summary", "Dashboard Summary", summary),
      section("participation", "Farmer Training Participation Status", participation),
      section("demonstration", "Demonstration Method", demo),
      section("other", "Main Major Work Indicator - Other", OTHER.map { |key, title|
        card("other_#{key}", title, other[key], "other_activities", unit: key == :achieved ? "percent" : "count")
      }), *groups,
      section("cc_jj_work_status", "CC and JJ Work Status", [],
        rows: MobileDashboardReportCards.cc_jj_rows(call_report.summary),
        groups: MobileDashboardReportCards.cc_jj_groups(call_report.summary),
        list_endpoint: "#{ROOT}/lists/cc_jj_work_status")]
  end

  def demonstration_cards
    call(:demonstration_method_cards).each_with_index.map do |item, index|
      parts = item[:value].to_s.split("/")
      value = parts.size == 2 ? { target: parts.first.to_f, achievement: parts.last.to_f } : item[:value]
      card(DEMO.fetch(index), item[:title], value, "demonstration_method")
    end
  end

  def other_rows
    return @other_rows if defined?(@other_rows)

    # Keep the web's secondary Other panel, preserving non-activity filters.
    targets = @targets.reject { |target| target.main_activity_name.to_s.strip.casecmp?("Farmers' Training") }
    if targets.empty?
      ids = Array(@calculator.instance_variable_get(:@filtered_vrps)).map(&:id).to_set
      month = @calculator.instance_variable_get(:@dashboard_month_filter_value)
      ics = call(:dashboard_filter_param, :ics, :ics_name)
      targets = call(:dashboard_target_mappings).select do |target|
        !target.main_activity_name.to_s.strip.casecmp?("Farmers' Training") && ids.include?(target.vrp_id) &&
          (month.blank? || target.month_name.to_s.casecmp?(month)) &&
          (ics.blank? || (target.ics_name.presence || target.ics_id).to_s.casecmp?(ics))
      end
    end
    return @other_rows = [] if targets.empty?

    # Unlike the legacy FCO aggregate, require the entry's JJ and selected
    # farmer to belong to these exact mappings before counting achievements.
    connection = TargetMapping.connection
    scope = TargetMapping.where(id: targets.map(&:id)).select(:vrp_id, :fco_id, :fco_name, :main_activity_name, :month_name, :afl_ids).to_sql
    @other_rows = connection.select_all(<<~SQL).to_a
      WITH mapping AS (
        SELECT DISTINCT t.vrp_id, t.fco_id, t.fco_name, t.main_activity_name,
          LOWER(TRIM(t.month_name)) AS month, f.id AS farmer_id
        FROM (#{scope}) t
        CROSS JOIN LATERAL jsonb_array_elements_text(t.afl_ids::jsonb) f(id)
      ), detail AS (
        SELECT m.*, EXISTS (
          SELECT 1 FROM module_records r
          WHERE r.module_slug = 'training-form'
            AND COALESCE(NULLIF(r.data::jsonb->>'vrp_id', ''),
              CASE WHEN LOWER(r.data::jsonb->>'created_by_record_type') = 'vrp'
              THEN r.data::jsonb->>'created_by_id' END) = m.vrp_id::text
            AND LOWER(TRIM(r.data::jsonb->>'month')) = m.month
            AND LOWER(TRIM(r.data::jsonb->>'main_activity')) = LOWER(TRIM(m.main_activity_name))
            AND COALESCE(r.data::jsonb->'selected_farmer_ids', '[]'::jsonb) @> to_jsonb(ARRAY[m.farmer_id])
        ) AS done FROM mapping m
      ) SELECT fco_id, fco_name, main_activity_name,
        COUNT(DISTINCT farmer_id) AS mapped_farmer,
        COUNT(DISTINCT farmer_id) FILTER (WHERE done) AS achievement_farmer,
        COUNT(DISTINCT farmer_id) - COUNT(DISTINCT farmer_id) FILTER (WHERE done) AS pending_farmer,
        (SELECT COUNT(DISTINCT farmer_id) FROM mapping) AS distinct_mapped_farmer
      FROM detail GROUP BY fco_id, fco_name, main_activity_name ORDER BY fco_name, main_activity_name
    SQL
  end

  def other_totals
    rows = other_rows
    mapped = rows.sum { |row| row["mapped_farmer"].to_i }
    done = rows.sum { |row| row["achievement_farmer"].to_i }
    { main_major_work_indicator: rows.map { |row| row["main_activity_name"] }.uniq.size,
      mapped_farmer: rows.first&.fetch("distinct_mapped_farmer", 0).to_i,
      achievement_farmer: done, pending_farmer: rows.sum { |row| row["pending_farmer"].to_i },
      achieved: mapped.positive? ? (100.0 * done / mapped).round(2) : 0 }
  end

  private

  def call(name, *args, **kwargs)
    @calculator.send(name, *args, **kwargs)
  end

  def call_report
    @report ||= CcJjWorkStatusReport.new(calculator: @calculator)
  end

  def card(key, title, value, list, **extra)
    { key: key, title: title, value: value, list_key: list,
      list_endpoint: "#{ROOT}/lists/#{list}", export_endpoint: "#{ROOT}/lists/#{list}/export", **extra }
  end

  def section(key, title, cards, **extra)
    { key: key, title: title, cards: cards, **extra }
  end
end
