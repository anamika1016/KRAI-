# Request-local adapter for the office-user API. The web, Admin and JJ
# dashboards continue to use ModulesController without these overrides.
class OfficeDashboardCalculator < ModulesController
  # The web dashboard resolves an Agronomist/Manager hierarchy through its
  # rendered controller state.  API requests start with a fresh controller, so
  # include the same Level-2/cluster JJs here before any month, ICS or activity
  # filter is applied.  Without this October mappings owned by those clusters
  # disappeared and every dashboard card became zero.
  def dashboard_vrps
    return @office_dashboard_vrps if defined?(@office_dashboard_vrps)

    own_scope = Array(super)
    hierarchy_scope = office_hierarchy_dashboard_reader? ? Array(dashboard_hierarchy_vrps) : []
    @office_dashboard_vrps = (own_scope + hierarchy_scope).uniq { |vrp| vrp.id }
  end

  # The month the Gender Count / FCO-wise JJ Requirement cards resolved to.
  # A drill-down list must not re-derive this from params: that skips the
  # All Months fallback applied in apply_dashboard_scope, so tapping a card
  # showing 33 opened a list filtered on an empty month and returned nothing.
  def dashboard_card_month
    month = @dashboard_month_filter_value.presence || params[:month].presence ||
      params[:training_month].presence
    return nil if month.to_s.casecmp("all").zero?

    month.presence
  end

  # The JJ scope the *web* dashboard builds for this same login.
  #
  # It cannot be taken from super: this class widens training_fcoc_filter_values
  # with extra FCO id/name aliases and adds the hierarchy expansion above, and
  # both of those feed scoped_jeevika_vrp_visible?. A Manager login therefore
  # resolved 15 visible JJs here where the web resolves 9. Cards that have to
  # report the web's own numbers ask an unmodified ModulesController instead.
  def web_dashboard_vrps
    @web_dashboard_vrps ||= begin
      web = ModulesController.new
      web.request = request
      web.params = params
      web.instance_variable_set(:@current_app_user, current_app_user)
      Array(web.send(:dashboard_vrps))
    rescue StandardError => error
      Rails.logger.warn("Web JJ scope lookup failed: #{error.class}: #{error.message}")
      Array(dashboard_vrps)
    end
  end

  def apply_dashboard_scope(vrps:, targets:, bills:, summary_vrps: nil, summary_targets: nil)
    @filtered_vrps = vrps
    @filtered_targets = targets
    @filtered_bills = bills
    @office_summary_vrps = summary_vrps
    @office_summary_targets = summary_targets
    @office_authorized_vrps ||= (defined?(@dashboard_vrps) && @dashboard_vrps.present? ? Array(@dashboard_vrps).dup : Array(vrps))
    @office_authorized_vrp_ids ||= @office_authorized_vrps.map(&:id).to_set
    if !defined?(@dashboard_vrps) || @dashboard_vrps.blank?
      @dashboard_vrps = @office_authorized_vrps
      @dashboard_visible_vrp_ids = @office_authorized_vrp_ids.to_a
    end
    # Keep the authorised web scope loaded before API filters. The web FCO/JJ,
    # billing, gender and CC/JJ cards use it for their own reporting queries.
    @dashboard_month_filter_value = params.key?(:month) ? dashboard_filter_param(:month) : DashboardDefaults.month
    # Same rule the web dashboard applies to its own default: the current month
    # has no data early on, so a caller that asked for no month in particular
    # gets All Months instead of a month whose every card reads zero. A month
    # the caller actually asked for is never second-guessed.
    if !params.key?(:month) && @dashboard_month_filter_value.present? &&
        !default_dashboard_month_on_offer?(@dashboard_month_filter_value, summary_targets || targets)
      @dashboard_month_filter_value = nil
    end
    @dashboard_fcoc_filter_value = dashboard_filter_param(:fcoc, :fco)
    # Same resolution as the web's TO filter, including the rule that a login
    # carrying its own Sub Office Name is pinned to that TO. Every card that
    # reads @dashboard_to_filter_value -- the Summary SQL, Demonstration
    # Method, Other -- then scopes to the selected TO without its own change.
    @dashboard_to_filter_value = dashboard_filter_param(:to_name, :to) ||
      dashboard_user_sub_office_to_value
  end

  private

  def default_dashboard_month_on_offer?(month, targets)
    wanted = normalize_dashboard_text(month)
    return false if wanted.blank?

    offered = Array(targets).map { |target| normalize_dashboard_text(target.month_name) }
    offered += Array(month_master_month_options).map { |option| normalize_dashboard_text(option) }
    offered.include?(wanted)
  rescue StandardError => error
    Rails.logger.warn("Default dashboard month lookup failed: #{error.class}: #{error.message}")
    true
  end

  def office_hierarchy_dashboard_reader?
    return true if dashboard_agronomics_login?

    office_dashboard_roles.any? { |role| role.include?("manager") }
  end

  # Use the configured FCO-C list only. Raw AFL/VRP data contains other
  # operational offices such as Bhabra and PAPL; those must not create cards.
  def dashboard_fco_names(vrps = nil)
    names = FcoDirectory.names
    selected = dashboard_filter_param(:fcoc, :fco)
    names.select! { |name| training_fcoc_text_matches?(name, selected) } if selected.present?
    names.sort_by { |name| normalize_dashboard_text(name) }
  rescue StandardError => error
    Rails.logger.warn("Dynamic API FCO names failed: #{error.class}: #{error.message}")
    FcoDirectory.names
  end

  # Gender Count and FCO-wise JJ Requirement are deliberately NOT rebuilt here.
  # They used to be, from the activity-filtered JJ set and the API's own month
  # fallback, which made every login read different numbers than the web it is
  # mirroring: a CC saw only its own JJs where the web shows the whole FCO, a
  # Manager saw more than the web because of the hierarchy expansion below, and
  # any month whose activity filter matched no JJ reported a flat zero (an
  # empty array is truthy, so the `||` chain never reached the fallback).
  # The web cards are the contract -- let them through untouched.
  def dashboard_report_fco_names(vrps, targets)
    dashboard_fco_names(vrps)
  end

  # AFL uses numeric IDs/plain names, while JJ records also use FCO-Direct to HO.
  # Expand equivalent labels only; the existing authorized JJ scope still decides
  # which offices the caller may see.
  def training_fcoc_filter_values(*values)
    # The parent caches its own half by argument list; this half did not, so the
    # lookup below -- and the fresh #invert it allocated -- ran once per row for
    # every dashboard loop. The same handful of FCO spellings repeat across
    # hundreds of rows, so cache this half the same way.
    @office_fcoc_filter_values_cache ||= {}
    return @office_fcoc_filter_values_cache[values] if @office_fcoc_filter_values_cache.key?(values)

    @office_fcoc_filter_values_cache[values] = super + Array(values).flatten.flat_map do |value|
      text = normalize_dashboard_text(value)
      short_name = text.sub(/\Afco(?:\s*[- ]?\s*c)?\s*[-:]?\s*/i, "").strip
      id, name = fco_name_by_id.find { |candidate_id, candidate_name| [candidate_id, candidate_name].include?(short_name) }
      id ? [id, name, "fco-c #{name}", "fco-#{name}"] : [short_name]
    end.reject(&:blank?).uniq
  end

  # id => name, built once per calculator rather than once per lookup.
  def fco_name_by_id
    @fco_name_by_id ||= FcoDirectory.id_by_name.invert
  end

  def compute_dashboard_source_fcoc_login
    super || office_dashboard_roles.any? { |role| role.match?(/\Afco(?:[-\s]|$)/) }
  end

  # The web result is authoritative. The only thing re-applied on top is the
  # approval rule: a stale target mapping naming a JJ who was never
  # final-approved must not count as Active. Nothing else may be re-filtered
  # here -- an is_active/is_deleted/authorised-scope pass on top is what made
  # these cards disagree with the web for every non-admin login.
  def dashboard_fco_active_vrp_records(fco, month = nil, _vrps = nil)
    month = nil if month.to_s.casecmp("all").zero?
    # web_dashboard_vrps, not the caller's list: when an FCO has no target
    # mapping for the month the web falls back to matching vrp.fcoc against
    # its own JJ scope, so an Agronomist/Manager login counted the whole
    # hierarchy here and read higher than the web it mirrors.
    records = super(fco, month, web_dashboard_vrps)
    approved_ids = dashboard_approved_vrps(records).map(&:id).to_set
    records.select { |vrp| approved_ids.include?(vrp.id) }
  end

  def dashboard_fco_active_vrp_count(fco, month = nil, vrps = nil)
    dashboard_fco_active_vrp_records(fco, month, vrps).size
  end

  def dashboard_summary_target_sql_filters_base(**_options)
    # The web Summary cards retain the login/FCO/ICS/JJ scope while the month,
    # main activity and sub-activity dropdowns drive the sections below them.
    conditions, binds = super(include_activity_filters: false)
    if defined?(@filtered_targets)
      conditions << "t.id IN (:office_target_ids)"
      binds[:office_target_ids] = @filtered_targets.map(&:id)
    end
    [conditions, binds]
  end

  # Reuse expensive presentation calculations within this request only.
  def dashboard_summary_cards(targets)
    return @office_summary_cards if defined?(@office_summary_cards)

    original_targets = @filtered_targets
    original_vrps = @filtered_vrps
    original_dashboard_vrps = @dashboard_vrps
    original_visible_vrp_ids = @dashboard_visible_vrp_ids
    begin
      unless @office_summary_targets.nil?
        @filtered_targets = Array(@office_summary_targets)
        @filtered_vrps = Array(@office_summary_vrps)
        @dashboard_vrps = Array(@office_summary_vrps)
        @dashboard_visible_vrp_ids = Array(@dashboard_vrps).map(&:id)
      end
      @office_summary_cards = super(@office_summary_targets.nil? ? targets : @office_summary_targets)
    ensure
      @filtered_targets = original_targets
      @filtered_vrps = original_vrps
      @dashboard_vrps = original_dashboard_vrps
      @dashboard_visible_vrp_ids = original_visible_vrp_ids
    end
  end

  # Keep historical target farmer IDs only when an old mapping has no
  # matching row in the current AFL import. Normal months retain the exact
  # web dashboard counts, including the valid difference between Total Farmer
  # Count and Mapped Farmer.
  def training_participation_existing_farmer_id_set(targets)
    current_ids = super
    return current_ids if current_ids.any?

    Set.new(Array(targets).flat_map { |target| target_farmer_ids(target) }
      .map(&:to_s).reject(&:blank?))
  end

  # The web Mapped Farmer card uses the authorized FCO/JJ base population
  # for a month. It deliberately does not restrict this card by main or sub
  # activity, even when those dropdowns are selected.
  def training_mapped_farmer_distinct_count_for_participation(month_name:, fcoc_name:, targets:)
    if month_name.present?
      return with_web_participation_status_scope do
        mapped, = farmer_training_mapped_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
        mapped.to_i
      end
    end

    Array(targets).flat_map { |target| target_farmer_ids(target) }
      .map(&:to_s).reject(&:blank?).uniq.size
  end

  # The web dashboard overwrites the generic participation calculation with
  # its final four card queries. Keep that exact behavior for all office APIs:
  # mapped target farmers, no-training farmers, one training and repeated training.
  def training_participation_dashboard_counts(month_name:, fcoc_name:, records:, targets: nil, week_number: nil)
    counts = super
    # The legacy final-card queries default a blank month to August. Preserve
    # the generic calculation for explicit month=All instead.
    return counts if month_name.blank? || week_number.present?

    participation_targets = targets || training_participation_targets_for_dashboard(
      month_name: month_name, fcoc_name: fcoc_name
    )
    mapped = training_mapped_farmer_distinct_count_for_participation(
      month_name: month_name, fcoc_name: fcoc_name, targets: participation_targets
    )

    # Historical month mappings can reference farmers removed by a later AFL
    # import. The web red/yellow/green cards therefore use the authorized base
    # JJ/FCO population, not the selected target array. Temporarily restore
    # that same base scope only for these status cards.
    red, yellow, green = with_web_participation_status_scope do
      # Activity dropdowns can leave the visible target set empty, but web
      # participation cards intentionally retain the login/FCO/ICS/JJ base.
      # Explicitly empty authorization scopes still remain empty.
      if @office_summary_targets.present? || @office_summary_vrps.present?
        @filtered_targets = Array(@office_summary_targets)
        @dashboard_vrps = Array(@office_summary_vrps)
        @dashboard_visible_vrp_ids = @dashboard_vrps.map(&:id)
      end
      red, = farmer_training_no_training_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
      yellow, = farmer_training_yellow_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
      green, = farmer_training_green_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
      [red, yellow, green]
    end

    if week_number.blank?
      red_rows = with_web_participation_status_scope do
        if @office_summary_targets.present? || @office_summary_vrps.present?
          @filtered_targets = Array(@office_summary_targets)
          @dashboard_vrps = Array(@office_summary_vrps)
          @dashboard_visible_vrp_ids = @dashboard_vrps.map(&:id)
        end
        farmer_training_participation_rows_from_sql("red", month_name: month_name, fcoc_name: fcoc_name)
      end
      if red_rows.empty?
        red_rows = training_participation_web_rows(status: "red", month_name: month_name, fcoc_name: fcoc_name)
      end
      @office_pending_participation_rows = red_rows
    end

    counts.merge(total: mapped.to_i, red: red.to_i, pending: red.to_i,
      yellow: yellow.to_i, green: green.to_i)
  end

  def with_web_participation_status_scope
    names = %i[@filtered_targets @dashboard_vrps @dashboard_visible_vrp_ids]
    saved = names.to_h { |name| [name, instance_variable_defined?(name) ? instance_variable_get(name) : :__missing__] }
    names.each { |name| remove_instance_variable(name) if instance_variable_defined?(name) }
    yield
  ensure
    saved&.each do |name, value|
      if value == :__missing__
        remove_instance_variable(name) if instance_variable_defined?(name)
      else
        instance_variable_set(name, value)
      end
    end
  end

  # Exact web View List rows for the four Participation cards. This keeps the
  # list query on the same authorized base population as its count card.
  def training_participation_web_rows(status:, month_name:, fcoc_name:)
    return Array(@office_pending_participation_rows) if status.to_s == "pending" && defined?(@office_pending_participation_rows)

    if month_name.blank?
      records = dashboard_training_participation_records(month_name: nil, fcoc_name: fcoc_name)
      rows = training_participation_population_rows(month_name: nil, fcoc_name: fcoc_name, records: records)
      rows = rows.select { |row| row[:status].to_s == (status == "pending" ? "red" : status) } unless %w[unique mapped].include?(status)
    else
      rows = with_web_participation_status_scope do
        sql_status = status.to_s == "pending" ? "red" : status.to_s
        farmer_training_participation_rows_from_sql(sql_status, month_name: month_name, fcoc_name: fcoc_name)
      end
      if %w[unique mapped].include?(status.to_s)
        historical_rows = historical_mapped_farmer_rows(month_name: month_name, fcoc_name: fcoc_name)
        existing_ids = rows.to_h { |row| [row[:farmer_id].to_s, true] }
        rows += historical_rows.reject { |row| existing_ids.key?(row[:farmer_id].to_s) }
      end
    end
    enrich_office_farmer_identifiers(rows)
  end

  # The web display serializer drops these SQL columns. Restore them in one
  # lookup for mobile clients, without changing list membership or web output.
  def enrich_office_farmer_identifiers(rows)
    columns = %i[id fco_id fco fpo_id fpo_name ics_id ics_name village_id village_name]
    farmers = Afl.where(id: rows.map { |row| row[:farmer_id] }).pluck(*columns)
      .to_h { |values| [values.first.to_s, columns.zip(values).to_h] }
    rows.each do |row|
      farmer = farmers[row[:farmer_id].to_s] || {}
      %i[fco_id fpo_id fpo_name ics_id ics_name village_id village_name].each do |key|
        row[key] = farmer[key].presence || row[key]
      end
      row[:fco_name] = farmer[:fco].presence || row[:fco_name] || row[:fcoc]
    end
    rows
  end

  def historical_mapped_farmer_rows(month_name:, fcoc_name:)
    with_web_participation_status_scope do
      targets = dashboard_target_mappings.select do |target|
        normalize_dashboard_text(target.month_name) == normalize_dashboard_text(month_name) &&
          (fcoc_name.blank? || training_target_matches_fcoc?(target, fcoc_name))
      end
      selected_ics = dashboard_filter_param(:ics, :ics_name)
      if selected_ics.present?
        targets.select! do |target|
          [target.ics_id, target.ics_name].any? do |value|
            normalize_dashboard_text(value) == normalize_dashboard_text(selected_ics)
          end
        end
      end

      target_by_farmer_id = {}
      targets.each do |target|
        target_farmer_ids(target).each { |farmer_id| target_by_farmer_id[farmer_id.to_s] ||= target }
      end
      farmers = Afl.where(id: target_by_farmer_id.keys).index_by { |farmer| farmer.id.to_s }
      target_by_farmer_id.map do |farmer_id, target|
        farmer = farmers[farmer_id]
        {
          farmer_id: farmer_id,
          fco_id: target.fco_id, fco_name: target.fco_name,
          fpo_id: farmer&.fpo_id, fpo_name: farmer&.fpo_name,
          ics_id: target.ics_id, ics_name: target.ics_name,
          village_id: target.village_id, village_name: target.village_name,
          vrp_id: target.vrp_id,
          farmer_name: farmer&.farmer_name.presence || "Historical mapped farmer ##{farmer_id}",
          father_name: farmer&.father_name.to_s,
          mobile_no: farmer&.mobile_no.to_s,
          tracenet_no: farmer&.tracenet_no.to_s,
          ics: target.ics_name.presence || target.ics_id.presence || "-",
          village: target.village_name.presence || target.village_id.presence || "-",
          fcoc: target.fco_name.presence || target.vrp&.fcoc.presence || target.fco_id.presence || "-",
          cluster_incharge: target.vrp&.cluster_incharge.presence || "-",
          jeevika_jankar_name: target.vrp&.name.presence || "-",
          vrp: target.vrp&.name.presence || "-",
          registered_by: target_mapping_registered_by_name(target).presence || "-",
          months: target.month_name.presence || month_name,
          main_activities: target.main_activity_name.presence || "-",
          sub_activities: target.activity_name.presence || "-",
          attendance_count: 0,
          status: "unique",
          status_label: "Mapped Farmer",
          historical_mapping: farmer.nil?,
          source: "target_mapping"
        }
      end.sort_by { |row| [row[:village].to_s, row[:farmer_name].to_s] }
    end
  end

  def training_registered_afl_farmer_count_for_participation(targets, fcoc_name: nil)
    current_count = super
    return current_count if current_count.positive?

    training_mapped_farmer_distinct_count_for_participation(month_name: nil, fcoc_name: fcoc_name, targets: targets)
  end

  def dashboard_summary_login_counts(targets)
    counts = super
    return counts if dashboard_global_view_user? || counts[:farmer_count].to_i.positive?

    rows = Array(targets)
    farmer_count = rows.flat_map { |target| target_farmer_ids(target) }
      .map(&:to_s).reject(&:blank?).uniq.size
    counts.merge(
      ics_count: rows.map { |target| [target.fco_id.to_s, target.ics_id.to_s, target.ics_name.to_s] }.reject { |_fco, id, name| id.blank? && name.blank? }.uniq.size,
      village_count: rows.map { |target| [target.fco_id.to_s, target.village_id.to_s, target.village_name.to_s] }.reject { |_fco, id, name| id.blank? && name.blank? }.uniq.size,
      farmer_count: farmer_count,
      mapped_farmer_count: farmer_count
    )
  end

  def demonstration_method_cards
    @demonstration_method_report ||= DemonstrationMethodReport.new(
      targets: @filtered_targets || dashboard_target_mappings,
      month: params.key?(:month) ? dashboard_filter_param(:month) : DashboardDefaults.month)
    super
  end

  def compute_dashboard_agronomics_login
    super || office_dashboard_roles.any? { |role| role.include?("agricultural specialist") }
  end

  def office_dashboard_roles
    %w[role role_name stakeholder_role user_management_role person_type designation].filter_map do |key|
      normalize_dashboard_user_label(current_app_user&.dig(key)).presence
    end
  end

  def scoped_jeevika_vrp_visible?(vrp)
    return super unless office_dashboard_roles.any? { |role| role == "manager ics" || role == "ics manager" }
    return false unless vrp

    # Hierarchy mappings are authorization data; never infer access to an
    # entire office just from a role name supplied by the client.
    jeevika_bill_vrp_registered_by_current_user?(vrp) ||
      (@office_hierarchy_vrp_ids ||= dashboard_hierarchy_vrps.map(&:id).to_set).include?(vrp.id)
  end

  def dashboard_participation_targets
    defined?(@filtered_targets) ? @filtered_targets : super
  end

  def module_record_visible_for_current_context?(record)
    return super unless record&.module_slug == "training-form"

    target_record_visible?(record)
  end

  def dashboard_training_participation_records(**options)
    if defined?(@filtered_targets) && @filtered_targets.empty?
      return with_web_participation_status_scope do
        @filtered_targets = Array(@office_summary_targets) if @office_summary_targets.present?
        @dashboard_vrps = Array(@office_summary_vrps) if @office_summary_vrps.present?
        @dashboard_visible_vrp_ids = @dashboard_vrps.map(&:id) if @dashboard_vrps.present?
        super(**options)
      end
    end

    super
  end


end
