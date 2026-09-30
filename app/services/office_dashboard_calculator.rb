# Request-local adapter for the office-user API. The web, Admin and JJ
# dashboards continue to use ModulesController without these overrides.
class OfficeDashboardCalculator < ModulesController
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
    @dashboard_fcoc_filter_value = dashboard_filter_param(:fcoc, :fco)
  end

  private

  # API-only dynamic FCO source. The web controller remains unchanged.
  def dashboard_fco_names(vrps = nil)
    names = Array(vrps || @office_authorized_vrps || dashboard_vrps).each_with_object({}) do |vrp, values|
      value = vrp.respond_to?(:fcoc) ? vrp.fcoc.to_s.squish : ""
      value = value.sub(/\Afco\s*(?:-\s*c)?\s*[-:]?\s*/i, "").squish
      values[normalize_dashboard_text(value)] ||= value if value.present?
    end
    names.values.sort_by { |name| normalize_dashboard_text(name) }
  end

  def dashboard_cards
    cards = super.reject { |group| ["Gender Count", "FCO-wise JJ Requirement"].include?(group[:title]) }
    vrps = Array(@office_authorized_vrps || dashboard_vrps)
    fco_names = dashboard_fco_names(vrps)
    month = params[:month].presence || params[:training_month].presence || DashboardDefaults.month
    gender_items = fco_names.flat_map do |fco_name|
      fco_vrps = dashboard_fco_active_vrp_records(fco_name, month, vrps)
      [
        { title: "#{fco_name} Male", value: fco_vrps.count { |vrp| normalize_dashboard_text(vrp.gender) == "male" } },
        { title: "#{fco_name} Female", value: fco_vrps.count { |vrp| normalize_dashboard_text(vrp.gender) == "female" } }
      ]
    end
    targets = @office_summary_targets.nil? ? @filtered_targets : @office_summary_targets
    cards << dashboard_group_card("Gender Count", gender_items, style: "registration")
    cards << dashboard_group_card("FCO-wise JJ Requirement",
      fco_names.flat_map { |fco_name| dashboard_jj_requirement_items(fco_name, vrps, targets) }, style: "fco")
    cards
  end

  # AFL uses numeric IDs/plain names, while JJ records also use FCO-Pavijetpur.
  # Expand equivalent labels only; the existing authorized JJ scope still decides
  # which offices the caller may see.
  OFFICE_FCO_NAMES = { "1004" => "sausar", "1006" => "turekela", "1095" => "pavijetpur" }.freeze

  def training_fcoc_filter_values(*values)
    super + Array(values).flatten.flat_map do |value|
      text = normalize_dashboard_text(value)
      short_name = text.sub(/\Afco(?:\s*[- ]?\s*c)?\s*[-:]?\s*/i, "").strip
      id, name = OFFICE_FCO_NAMES.find { |id, name| [id, name].include?(short_name) }
      id ? [id, name, "fco-c #{name}", "fco-#{name}"] : [short_name]
    end.reject(&:blank?).uniq
  end

  def compute_dashboard_source_fcoc_login
    super || office_dashboard_roles.any? { |role| role.match?(/\Afco(?:[-\s]|$)/) }
  end

  # Use the same month/FCO target query as the web cards, then keep only JJs
  # already authorised for this API login. This prevents activity filters from
  # shrinking card values and prevents the SQL helper from exposing other JJs.
  def dashboard_fco_active_vrp_records(fco, month = nil, vrps = nil)
    candidates = super(fco, month, @office_authorized_vrps || vrps)
    candidates.select { |vrp| @office_authorized_vrp_ids.include?(vrp.id) }
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
    return 0 if defined?(@filtered_targets) && @filtered_targets.empty?

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
    if defined?(@filtered_targets) && @filtered_targets.empty?
      return counts.merge(total: 0, target_map_total: 0, completed_target_map_total: 0,
        red: 0, pending: 0, yellow: 0, green: 0)
    end
    # The legacy final-card queries default a blank month to August. Preserve
    # the generic calculation for explicit month=All instead.
    return counts if month_name.blank?

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
      red, = farmer_training_no_training_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
      yellow, = farmer_training_yellow_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
      green, = farmer_training_green_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
      [red, yellow, green]
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
    return [] if defined?(@filtered_targets) && @filtered_targets.empty?

    if month_name.blank?
      records = dashboard_training_participation_records(month_name: nil, fcoc_name: fcoc_name)
      rows = training_participation_population_rows(month_name: nil, fcoc_name: fcoc_name, records: records)
      rows = rows.select { |row| row[:status].to_s == (status == "pending" ? "red" : status) } unless %w[unique mapped].include?(status)
    else
      rows = with_web_participation_status_scope do
        farmer_training_participation_rows_from_sql(status.to_s, month_name: month_name, fcoc_name: fcoc_name)
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
    return [] if defined?(@filtered_targets) && @filtered_targets.empty?

    super
  end


end
