# Request-local adapter for the office-user API. The web, Admin and JJ
# dashboards continue to use ModulesController without these overrides.
class OfficeDashboardCalculator < ModulesController
  def apply_dashboard_scope(vrps:, targets:, bills:)
    @filtered_vrps = vrps
    @filtered_targets = targets
    @filtered_bills = bills
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

  # The legacy SQL summary rebuilds targets from the entire table and ignores
  # the supplied target array (notably activity and JJ selections). Use the
  # existing membership calculation for this API's explicitly filtered scope.
  def training_participation_dashboard_counts_from_sql(**)
    nil
  end

  def training_mapped_farmer_distinct_count_for_participation(month_name:, fcoc_name:, targets:)
    ids = Array(targets).flat_map { |target| Array(target.afl_ids) }.map(&:to_s).uniq
    return 0 if ids.empty?

    Afl.where(id: ids).distinct.count(Arel.sql(<<~SQL.squish))
      CASE WHEN LOWER(BTRIM(COALESCE(tracenet_no, ''))) NOT IN ('', 'null')
      THEN CONCAT('tracenet:', LOWER(BTRIM(tracenet_no)))
      ELSE CONCAT('id:', id::text) END
    SQL
  end

  def training_registered_afl_farmer_count_for_participation(targets, fcoc_name: nil)
    return 0 if defined?(@filtered_vrps) && @filtered_vrps.empty?

    super
  end
end
