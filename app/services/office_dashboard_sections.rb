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
        list_endpoint: "#{ROOT}/lists/cc_jj_work_status", export_endpoint: "#{ROOT}/lists/cc_jj_work_status/export")]
  end

  def demonstration_cards
    call(:demonstration_method_cards).each_with_index.map do |item, index|
      parts = item[:value].to_s.split("/")
      value = parts.size == 2 ? { target: parts.first.to_f, achievement: parts.last.to_f } : item[:value]
      card(DEMO.fetch(index), item[:title], value, "demonstration_method")
    end
  end

  # The Other cards and their View List must use the same reporting query as
  # the web dashboard. That query also handles the Farmers' Training filter by
  # restoring the matching Other mappings while retaining the selected month,
  # FCO, ICS, CC and JJ scope.
  def other_rows
    @other_rows ||= Array(call(:dashboard_other_activity_rows, @targets))
  end

  def other_totals
    @other_totals ||= begin
      totals = call(:dashboard_other_activity_totals, @targets)
      {
        main_major_work_indicator: totals[:main_major_work_indicator].to_i,
        mapped_farmer: totals[:mapped_farmer].to_i,
        achievement_farmer: totals[:achievement_farmer].to_i,
        pending_farmer: totals[:pending_farmer].to_i,
        achieved: totals[:achieved].to_f
      }
    end
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
