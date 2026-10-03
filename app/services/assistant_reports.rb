# Download URLs are selected from existing application routes, never AI output.
# The destination controller rechecks login, visibility and report permissions.
class AssistantReports
  FILTERS = %w[month training_month fcoc fco_id ics ics_name main_activity sub_activity].freeze
  REPORTS = [
    ["summary", "Dashboard summary / JJ gender counts", "/assistant/summary.xlsx", "summary gender male female dashboard"],
    ["farmers", "Farmer list", "/afls.xlsx", "farmer farmers afl kisan किसान"],
    ["villages", "Village summary", "/afls.xlsx?summary_mode=village", "village villages gaon गाँव"],
    ["ics", "ICS summary", "/afls.xlsx?summary_mode=ics", "ics"],
    ["participation", "Farmer training participation", "/dashboard/farmer-training-participation.xlsx", "participation training attendance"],
    ["target-status", "Farmer training target status", "/dashboard/farmer-training-target-status.xlsx", "target status training"],
    ["weekly", "Weekly activity target report", "/dashboard/weekly-activity-target-report.xlsx", "weekly activity target"],
    ["ics-report", "ICS-wise farmer report", "/dashboard/ics-wise-farmer-report.xlsx", "ics farmer report"],
    ["demonstration", "Demonstration method", "/dashboard/demonstration-method.xlsx", "demonstration opg ffs demo"],
    ["work-status", "CC / JJ work status", "/dashboard/cc-jj-work-status.xlsx", "cc jj work status"],
    ["cc-target", "CC target status", "/dashboard/cc-target-status.xlsx", "cc target status"]
  ].freeze

  def self.catalog
    REPORTS.map { |id, title, path, keywords| { id: id, title: title, path: path, keywords: keywords } } +
      ModulesController::MODULES.map do |slug, definition|
        { id: "module-#{slug}", title: definition[:title], path: "/modules/#{slug}/export.xlsx", keywords: "#{slug.tr('-', ' ')} #{definition[:title]}" }
      end
  end

  def self.filters(question, page_filters = {})
    values = page_filters.to_h.stringify_keys.slice(*FILTERS).transform_values { |v| v.to_s.first(100) }.reject { |_, v| v.blank? }
    month = Date::MONTHNAMES.compact.find { |name| question.match?(/\b#{name}\b/i) }
    values.merge!("month" => month, "training_month" => month) if month
    FcoDirectory.id_by_name.each do |name, id|
      values.merge!("fcoc" => name, "fco_id" => id) if question.match?(/\b(?:#{name}|#{id})\b/i)
    end
    values
  end

  def self.search(question, filters: {})
    words = question.downcase.scan(/[[:alnum:]]+/) - %w[excel excle xlsx export download data list report chahiye do de mujhe please format me mein]
    ranked = catalog.map do |report|
      score = words.count { |word| report[:keywords].downcase.split.include?(word) }
      [report, score]
    end.select { |_, score| score.positive? }.sort_by { |_, score| -score }
    ranked.first(8).map { |report, _| link(report, filters) }
  end

  def self.link(report, filters = {})
    path, query = report.fetch(:path).split("?", 2)
    filters = {} if report.fetch(:id).start_with?("module-")
    values = filters.to_h.stringify_keys.slice(*FILTERS).merge(Rack::Utils.parse_nested_query(query.to_s))
    { title: report.fetch(:title) + (report.fetch(:id).start_with?("module-") ? " (all visible records)" : ""), url: "#{path}#{values.empty? ? '' : '?' + values.to_query}", kind: "excel" }
  end
end
