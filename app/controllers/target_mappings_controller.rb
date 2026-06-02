class TargetMappingsController < ApplicationController
  def index
    @vrps = mapped_vrps
    @month_options = module_options("month-master", "month_name")
    @main_activity_options = module_options("add-activity-group", "main_activity_name", "activity_group_name")
    @sub_activity_options = module_options("add-vrp-activity", "sub_activity_name", "activity_name", "vrp_activity_name")
    @target_mappings = TargetMapping.includes(:vrp, :vrp_ics_mapping).order(updated_at: :desc).limit(100)
    @edit_target = TargetMapping.find_by(id: params[:edit_id]) if params[:edit_id].present?
    @edit_payload = edit_payload(@edit_target)
  end

  def create
    mapping = VrpIcsMapping.find(target_mapping_params[:vrp_ics_mapping_id])
    target_mapping = editable_target || TargetMapping.new
    target_mapping.assign_attributes(target_mapping_params)
    target_mapping.assign_attributes(mapping_attributes(mapping))

    if target_mapping.save
      redirect_to target_mappings_path, notice: "Target mapping saved successfully."
    else
      redirect_to target_mappings_path, alert: target_mapping.errors.full_messages.to_sentence
    end
  end

  def destroy
    TargetMapping.find(params[:id]).destroy
    redirect_to target_mappings_path, notice: "Target mapping deleted successfully."
  end

  def vrp_mappings
    render json: { mappings: mappings_for(params[:vrp_id]) }
  end

  private

  def target_mapping_params
    params.require(:target_mapping).permit(:vrp_id, :vrp_ics_mapping_id, :month_name, :main_activity_name, :activity_name, :target_quantity)
  end

  def editable_target
    return if params.dig(:target_mapping, :id).blank?

    TargetMapping.find(params.dig(:target_mapping, :id))
  end

  def mapped_vrps
    Vrp.where(id: VrpIcsMapping.select(:vrp_id).distinct).order(:name, :id)
  end

  def mappings_for(vrp_id)
    return [] if vrp_id.blank?

    VrpIcsMapping.where(vrp_id: vrp_id)
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
