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

    if target_mapping.save
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
    params.require(:target_mapping).permit(:vrp_id, :vrp_ics_mapping_id, :month_name, :main_activity_name, :activity_name, :target_quantity)
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
          farmer_count: mapping.farmer_count
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
      village_name: mapping.village_name,
      farmer_count: mapping.farmer_count
    }
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
      target_quantity: target.target_quantity.to_s
    }
  end
end
