# Request-local adapter for the office-user API. The web, Admin and JJ
# dashboards continue to use ModulesController without these overrides.
class OfficeDashboardCalculator < ModulesController
  def apply_dashboard_scope(vrps:, targets:, bills:, summary_vrps: nil, summary_targets: nil)
    @filtered_vrps = vrps
    @filtered_targets = targets
    @filtered_bills = bills
    @office_summary_vrps = summary_vrps
    @office_summary_targets = summary_targets
    @dashboard_vrps = vrps
    @dashboard_visible_vrp_ids = vrps.map(&:id)
    @dashboard_month_filter_value = params.key?(:month) ? dashboard_filter_param(:month) : Date.current.prev_month.strftime("%B")
    @dashboard_fcoc_filter_value = dashboard_filter_param(:fcoc, :fco)
  end

  private

  # These web helpers otherwise reload every JJ in an FCO, bypassing the
  # caller's filtered population. Keep the correction local to the mobile API.
  def dashboard_fco_active_vrp_records(fco, month = nil, vrps = nil)
    rows = Array(@filtered_targets).select { |target| training_fcoc_text_matches?(target.vrp&.fcoc, fco) }
    ids = rows.map(&:vrp_id).to_set
    Array(vrps || @filtered_vrps).select { |vrp| ids.include?(vrp.id) }
  end

  def dashboard_fco_active_vrp_count(fco, month = nil, vrps = nil)
    dashboard_fco_active_vrp_records(fco, month, vrps).size
  end

  def dashboard_billing_records
    defined?(@filtered_bills) ? @filtered_bills : super
  end

  def dashboard_summary_target_sql_filters_base(**options)
    conditions, binds = super
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
      if @office_summary_targets.present?
        @filtered_targets = @office_summary_targets
        @filtered_vrps = @office_summary_vrps if @office_summary_vrps.present?
        @dashboard_vrps = @office_summary_vrps if @office_summary_vrps.present?
        @dashboard_visible_vrp_ids = Array(@dashboard_vrps).map(&:id)
      end
      @office_summary_cards = super(@office_summary_targets.presence || targets)
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

  # Count only farmers in the target mappings authorized for this API request.
  def training_mapped_farmer_distinct_count_for_participation(month_name:, fcoc_name:, targets:)
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
    return counts if month_name.blank?

    mapped, = farmer_training_mapped_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
    red, = farmer_training_no_training_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
    yellow, = farmer_training_yellow_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
    green, = farmer_training_green_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)

    counts.merge(total: mapped.to_i, red: red.to_i, pending: red.to_i,
      yellow: yellow.to_i, green: green.to_i)
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
      month: params.key?(:month) ? dashboard_filter_param(:month) : Date.current.prev_month.strftime("%B"))
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

  def dashboard_visible_target_scope
    return super unless defined?(@filtered_targets)

    super.where(id: @filtered_targets.map(&:id))
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
