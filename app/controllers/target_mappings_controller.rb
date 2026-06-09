class TargetMappingsController < ApplicationController
  before_action :block_vrp_target_write, only: [:create, :destroy]

  def index
    @vrp_target_view = non_admin_vrp_login?
    @admin_mapping_actions = admin_login?
    @remove_mapping_actions = !admin_login? && !non_admin_vrp_login?
    @vrps = mapped_vrps
    @month_options = module_options("month-master", "month_name")
    @main_activity_options = module_options("add-activity-group", "main_activity_name", "activity_group_name")
    @sub_activity_options = module_options("add-vrp-activity", "sub_activity_name", "activity_name", "vrp_activity_name")
    @target_mappings = visible_target_mappings.includes(:vrp, :vrp_ics_mapping).order(updated_at: :desc).limit(100)
    @edit_target = visible_target_mappings.find_by(id: params[:edit_id]) if params[:edit_id].present? && @admin_mapping_actions
    @edit_payload = edit_payload(@edit_target)
  end

  def create
    mapping = visible_vrp_ics_mappings.find(target_mapping_params[:vrp_ics_mapping_id])
    target_mapping = editable_target || TargetMapping.new
    target_mapping.assign_attributes(target_mapping_params)
    target_mapping.assign_attributes(mapping_attributes(mapping))
    assign_creator(target_mapping) if target_mapping.new_record?

    if assign_target_farmers(target_mapping, mapping) && target_mapping.save
      redirect_to target_mappings_path, notice: "Target mapping saved successfully."
    else
      redirect_to target_mappings_path, alert: target_mapping.errors.full_messages.to_sentence
    end
  end

  def destroy
    visible_target_mappings.find(params[:id]).destroy
    redirect_to target_mappings_path, notice: admin_login? ? "Target mapping deleted successfully." : "Target mapping removed successfully."
  end

  def vrp_mappings
    render json: { mappings: mappings_for(params[:vrp_id]) }
  end

  private

  def block_vrp_target_write
    return unless non_admin_vrp_login?

    redirect_to target_mappings_path, alert: "VRP target records are view only for VRP login."
  end

  def target_mapping_params
    params.require(:target_mapping).permit(:vrp_id, :vrp_ics_mapping_id, :month_name, :main_activity_name, :activity_name, :target_quantity, afl_ids: [])
  end

  def editable_target
    return if params.dig(:target_mapping, :id).blank?

    visible_target_mappings.find(params.dig(:target_mapping, :id))
  end

  def mapped_vrps
    return Vrp.where(id: current_app_user["id"]).order(:name, :id) if non_admin_vrp_login?

    Vrp.where(id: visible_vrp_ics_mappings.select(:vrp_id).distinct).order(:name, :id)
  end

  def mappings_for(vrp_id)
    return [] if vrp_id.blank?

    visible_vrp_ics_mappings.where(vrp_id: vrp_id)
      .order(:fco_name, :ics_name, :village_name, :id)
      .map do |mapping|
        {
          id: mapping.id,
          fco: mapping.fco_name.presence || mapping.fco_id,
          ics: mapping.ics_name.presence || mapping.ics_id,
          village: mapping.village_name.presence || mapping.village_id,
          farmer_count: mapping.farmer_count,
          farmers: farmers_for_mapping(mapping, edit_target_for_json, params[:month_name])
        }
      end
  end

  def mapping_attributes(mapping)
    {
      vrp_id: mapping.vrp_id,
      fco_id: mapping.fco_id,
      fco_name: mapping.fco_name,
      ics_id: mapping.ics_id,
      ics_name: mapping.ics_name,
      village_id: mapping.village_id,
      village_name: mapping.village_name
    }
  end

  def assign_target_farmers(target_mapping, mapping)
    mapped_farmer_ids = normalized_afl_ids(mapping.afl_ids)
    target_count = target_farmer_count(target_mapping)
    return false unless target_count

    if target_count > mapped_farmer_ids.size
      target_mapping.errors.add(:target_quantity, "cannot be greater than registered farmers")
      return false
    end

    assigned_ids = assigned_farmer_ids_for(mapping, target_mapping, target_mapping.month_name)
    available_ids = mapped_farmer_ids - assigned_ids
    selected_ids = if target_count == mapped_farmer_ids.size
      mapped_farmer_ids
    else
      normalized_afl_ids(target_mapping_params[:afl_ids])
    end

    if target_count < mapped_farmer_ids.size && selected_ids.size != target_count
      target_mapping.errors.add(:afl_ids, "select exactly #{target_count} farmers")
      return false
    end

    invalid_ids = selected_ids - mapped_farmer_ids
    if invalid_ids.any?
      target_mapping.errors.add(:afl_ids, "include farmers outside this VRP ICS mapping")
      return false
    end

    blocked_ids = selected_ids & assigned_ids
    if blocked_ids.any?
      target_mapping.errors.add(:afl_ids, "#{blocked_ids.size} farmer already assigned in this month")
      return false
    end

    if target_count > available_ids.size
      target_mapping.errors.add(:target_quantity, "has only #{available_ids.size} unassigned farmers available in this month")
      return false
    end

    target_mapping.afl_ids = selected_ids
    target_mapping.farmer_count = selected_ids.size
    true
  end

  def target_farmer_count(target_mapping)
    quantity = BigDecimal(target_mapping.target_quantity.to_s)
    if quantity < 0 || quantity != quantity.to_i
      target_mapping.errors.add(:target_quantity, "must be a whole number of farmers")
      return nil
    end

    quantity.to_i
  rescue ArgumentError
    target_mapping.errors.add(:target_quantity, "is not a number")
    nil
  end

  def farmers_for_mapping(mapping, edit_target = nil, month_name = nil)
    ids = normalized_afl_ids(mapping.afl_ids)
    return [] if ids.blank? || !defined?(Afl) || !Afl.table_exists?

    assigned_ids = assigned_farmer_ids_for(mapping, edit_target, month_name.presence || edit_target&.month_name)
    selected_ids = normalized_afl_ids(edit_target&.afl_ids)

    Afl.where(id: ids)
      .order(:farmer_name, :id)
      .map do |afl|
        {
          id: afl.id.to_s,
          farmer_name: afl.farmer_name,
          father_name: afl.father_name,
          tracenet_no: afl.tracenet_no,
          mobile_no: afl.mobile_no,
          khasara_no: afl.khasara_no,
          assigned_to_other: assigned_ids.include?(afl.id.to_s),
          selected: selected_ids.include?(afl.id.to_s)
        }
      end
  end

  def assigned_farmer_ids_for(mapping, target_mapping = nil, month_name = nil)
    scope = TargetMapping.where(vrp_id: mapping.vrp_id)
    scope = scope.where(month_name: month_name) if month_name.present?
    scope = scope.where.not(id: target_mapping.id) if target_mapping&.persisted?
    scope.pluck(:afl_ids).flat_map { |ids| normalized_afl_ids(ids) }.uniq
  end

  def normalized_afl_ids(ids)
    parsed_ids = ids.is_a?(String) ? JSON.parse(ids) : ids
    Array(parsed_ids).map(&:to_s).reject(&:blank?).uniq
  rescue JSON::ParserError
    []
  end

  def module_options(module_slug, *field_keys)
    return [] unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    ModuleRecord.where(module_slug: module_slug)
      .order(created_at: :desc)
      .select { |record| record.data["status"].blank? || record.data["status"] == "Active" }
      .filter_map { |record| field_keys.filter_map { |field| record.data[field].presence }.first }
      .uniq
  end

  def visible_target_mappings
    return TargetMapping.all if admin_login?
    return TargetMapping.where(vrp_id: current_app_user["id"]) if non_admin_vrp_login?

    TargetMapping.where(created_by_type: current_app_user["record_type"], created_by_id: current_app_user["id"])
  end

  def visible_vrp_ics_mappings
    return VrpIcsMapping.all if admin_login?
    return VrpIcsMapping.where(vrp_id: current_app_user["id"]) if non_admin_vrp_login?

    VrpIcsMapping.where(created_by_type: current_app_user["record_type"], created_by_id: current_app_user["id"])
  end

  def assign_creator(record)
    record.created_by_type = current_app_user["record_type"]
    record.created_by_id = current_app_user["id"]
  end

  def edit_target_for_json
    return @edit_target_for_json if defined?(@edit_target_for_json)

    @edit_target_for_json = params[:edit_id].present? ? visible_target_mappings.find_by(id: params[:edit_id]) : nil
  end

  def admin_login?
    current_app_user["user_type"].to_s.strip.casecmp("admin").zero?
  end

  def non_admin_vrp_login?
    !admin_login? && current_app_user["record_type"].to_s == "Vrp"
  end

  def edit_payload(target)
    return {} unless target

    {
      id: target.id,
      vrp_id: target.vrp_id.to_s,
      vrp_ics_mapping_id: target.vrp_ics_mapping_id.to_s,
      target_quantity: target.target_quantity.to_s,
      afl_ids: Array(target.afl_ids).map(&:to_s)
    }
  end
end
