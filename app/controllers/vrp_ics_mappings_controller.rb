class VrpIcsMappingsController < ApplicationController
  def index
    @approved_vrps = approved_vrps
    @fco_options = fco_options
    @mappings = VrpIcsMapping.includes(:vrp).order(updated_at: :desc).limit(100)
    @edit_mapping = VrpIcsMapping.find_by(id: params[:edit_id]) if params[:edit_id].present?
    @edit_payload = edit_payload(@edit_mapping)
  end

  def create
    mapping = editable_mapping || VrpIcsMapping.find_or_initialize_by(mapping_identity_params)
    update_attrs = mapping_update_params.to_h
    update_attrs[:afl_ids] = [] unless update_attrs.key?("afl_ids") || update_attrs.key?(:afl_ids)
    mapping.assign_attributes(mapping_identity_params.merge(update_attrs))

    blocked_ids = already_mapped_farmer_ids(mapping) & Array(mapping.afl_ids).map(&:to_s)
    if blocked_ids.any?
      redirect_to vrp_ics_mappings_path(edit_id: mapping.persisted? ? mapping.id : nil), alert: "#{blocked_ids.size} farmer already mapped in another VRP ICS mapping."
      return
    end

    if mapping.save
      redirect_to vrp_ics_mappings_path, notice: "#{mapping.farmer_count} farmer mapped successfully."
    else
      redirect_to vrp_ics_mappings_path, alert: mapping.errors.full_messages.to_sentence
    end
  end

  def destroy
    VrpIcsMapping.find(params[:id]).destroy
    redirect_to vrp_ics_mappings_path, notice: "VRP ICS mapping deleted successfully."
  end

  def ics_options
    render json: { options: ics_options_for(params[:fco_id]) }
  end

  def village_options
    render json: { options: village_options_for(params[:fco_id], params[:ics_id]) }
  end

  def farmers
    render json: { farmers: farmers_for(params[:fco_id], params[:ics_id], params[:village_id], params[:edit_id]) }
  end

  private

  def editable_mapping
    return if params.dig(:vrp_ics_mapping, :id).blank?

    VrpIcsMapping.find(params.dig(:vrp_ics_mapping, :id))
  end

  def mapping_identity_params
    params.require(:vrp_ics_mapping).permit(:vrp_id, :fco_id, :ics_id, :village_id)
  end

  def mapping_update_params
    params.require(:vrp_ics_mapping).permit(:fco_name, :ics_name, :village_name, afl_ids: [])
  end

  def approved_vrps
    scope = Vrp.where(status: 55)
    scope = scope.where(is_active: true) if Vrp.column_names.include?("is_active")
    scope.order(:name, :id)
  end

  def fco_options
    Afl.where.not(fco_id: [nil, ""])
      .select(:fco_id, :fco)
      .distinct
      .order(:fco, :fco_id)
      .map { |afl| option_hash(afl.fco_id, afl.fco) }
  end

  def ics_options_for(fco_id)
    return [] if fco_id.blank?

    Afl.where(fco_id: fco_id)
      .where.not(ics_id: [nil, ""])
      .select(:ics_id, :ics_name)
      .distinct
      .order(:ics_name, :ics_id)
      .map { |afl| option_hash(afl.ics_id, afl.ics_name) }
  end

  def village_options_for(fco_id, ics_id)
    return [] if fco_id.blank? || ics_id.blank?

    Afl.where(fco_id: fco_id, ics_id: ics_id)
      .where.not(village_id: [nil, ""])
      .select(:village_id, :village_name)
      .distinct
      .order(:village_name, :village_id)
      .map { |afl| option_hash(afl.village_id, afl.village_name) }
  end

  def farmers_for(fco_id, ics_id, village_id, edit_id = nil)
    return [] if fco_id.blank? || ics_id.blank? || village_id.blank?

    blocked_ids = already_mapped_farmer_ids(VrpIcsMapping.find_by(id: edit_id))

    Afl.where(fco_id: fco_id, ics_id: ics_id, village_id: village_id)
      .select(:id, :farmer_name, :father_name, :tracenet_no, :mobile_no, :khasara_no)
      .order(:farmer_name, :id)
      .map do |afl|
        {
          id: afl.id,
          farmer_name: afl.farmer_name,
          father_name: afl.father_name,
          tracenet_no: afl.tracenet_no,
          mobile_no: afl.mobile_no,
          khasara_no: afl.khasara_no,
          mapped_to_other: blocked_ids.include?(afl.id.to_s)
        }
      end
  end

  def already_mapped_farmer_ids(mapping = nil)
    scope = VrpIcsMapping.all
    scope = scope.where.not(id: mapping.id) if mapping&.persisted?
    scope.pluck(:afl_ids).flat_map { |ids| normalized_afl_ids(ids) }.uniq
  end

  def normalized_afl_ids(ids)
    parsed_ids = ids.is_a?(String) ? JSON.parse(ids) : ids
    Array(parsed_ids).map(&:to_s)
  rescue JSON::ParserError
    []
  end

  def edit_payload(mapping)
    return {} unless mapping

    {
      id: mapping.id,
      vrp_id: mapping.vrp_id.to_s,
      fco_id: mapping.fco_id.to_s,
      ics_id: mapping.ics_id.to_s,
      village_id: mapping.village_id.to_s,
      afl_ids: Array(mapping.afl_ids).map(&:to_s)
    }
  end

  def option_hash(value, label)
    text = [label.presence, value].compact.join(" - ")
    { value: value, label: text.presence || value.to_s }
  end
end
