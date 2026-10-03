# Only aggregate data visible to the signed-in dashboard user is sent to the AI.
class AssistantContext
  FILTERS = %w[month training_month ics ics_name fcoc fco_id].freeze

  def initialize(controller, filters: {})
    @controller = controller
    @filters = filters.to_h.stringify_keys.slice(*FILTERS).transform_values { |value| value.to_s.first(100) }
  end

  def call(messages)
    return { data_available: false } if @controller.send(:current_app_user).blank?

    policy = ModulesController.new
    policy.request = @controller.request
    policy.instance_variable_set(:@current_app_user, @controller.send(:current_app_user))
    question = Array(messages).reverse.filter_map { |m| m["content"] if m.is_a?(Hash) && m["role"] == "user" }.first.to_s
    @filters = AssistantReports.filters(question, @filters).slice(*FILTERS)
    month = Date::MONTHNAMES.compact.find { |name| question.match?(/\b#{name}\b/i) }
    month ||= @filters["month"].presence || @filters["training_month"].presence || DashboardDefaults.month
    # The dashboard reads the FCO from :fcoc / :fco, so an fco_id-style filter
    # has to arrive under that key or an FCO-specific question is answered with
    # project-wide totals.
    fco_param = @filters["fcoc"].presence || @filters["fco_id"].presence
    policy.params = ActionController::Parameters.new(@filters.merge("month" => month, "fcoc" => fco_param).compact)
    vrps = policy.send(:dashboard_vrps)
    visible_ids = vrps.map(&:id)
    gender = FcoDirectory.names.map do |fco|
      # The dashboard helper can fetch additional VRPs. Intersect again to
      # prevent those records crossing the current user's visibility boundary.
      records = policy.send(:dashboard_fco_active_vrp_records, fco, month, vrps).select { |vrp| visible_ids.include?(vrp.id) }
      { fco: fco, male: records.count { |v| v.gender.to_s.strip.casecmp("male").zero? },
        female: records.count { |v| v.gender.to_s.strip.casecmp("female").zero? } }
    end
    fco = @filters["fco_id"].presence || @filters["fcoc"].presence
    if fco.present? && !fco.downcase.start_with?("all")
      canonical = FcoDirectory.name_by_id[fco]&.downcase || fco.sub(/\Afco\s*-\s*c\s+/i, "").downcase
      gender = gender.select { |row| policy.send(:training_fcoc_text_matches?, row[:fco], canonical) }
    end
    {
      source: "Signed-in user's dashboard", month: month,
      scope: "Visible records only. Gender counts are active JJ/VRPs, not farmers. JJ gender is scoped by FCO/month/user visibility (not ICS). Farmer totals are all-month visible totals; farmer FCO: #{fco.presence || 'all visible'}. ICS: #{@filters["ics"].presence || @filters["ics_name"].presence || 'all visible'}.",
      jj_gender_by_fco: gender,
      # Reuse the dashboard's own card queries. Counting the raw visible farmer
      # scope here instead reported every AFL row -- including other FCOs and
      # rows with no tracenet number -- so the assistant quoted totals far
      # larger than the Dashboard Summary the user was looking at.
      farmers: policy.send(:dashboard_total_afl_farmer_count),
      villages: policy.send(:dashboard_total_afl_village_count),
      ics: policy.send(:dashboard_total_afl_ics_count),
      modules: ModulesController::MODULES.map { |slug, definition| { slug: slug, title: definition[:title], purpose: definition[:purpose], fields: definition[:fields] } }
    }
  end
end
