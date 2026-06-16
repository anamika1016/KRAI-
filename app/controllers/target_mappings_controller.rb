class TargetMappingsController < ApplicationController
  before_action :block_vrp_target_write, only: [:create, :destroy]

  def index
    @vrp_target_view = non_admin_vrp_login?
    @admin_mapping_actions = admin_login?
    @remove_mapping_actions = !admin_login? && !non_admin_vrp_login?
    @vrps = target_vrps
    @month_options = module_options("month-master", "month_name")
    @main_activity_options = module_options("add-activity-group", "main_activity_name", "activity_group_name")
    @target_sub_activity_map = target_sub_activity_map
    @target_mappings = visible_target_mappings.includes(:vrp, :vrp_ics_mapping).order(updated_at: :desc).limit(100)
    @edit_target = visible_target_mappings.find_by(id: params[:edit_id]) if params[:edit_id].present? && @admin_mapping_actions
    @edit_payload = edit_payload(@edit_target)
    @sub_activity_options = target_sub_activity_options(@edit_target&.main_activity_name)
  end

  def create
    target_mapping = editable_target || TargetMapping.new
    target_mapping.assign_attributes(target_mapping_params)
    target_mapping.vrp_ics_mapping_id = nil
    normalize_location_values(target_mapping)
    assign_afl_location_names(target_mapping)
    assign_creator(target_mapping) if target_mapping.new_record?

    if assign_target_farmers(target_mapping) && target_mapping.save
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
    render json: {
      fco_options: fco_options,
      ics_options: ics_options_for(params[:fco_id]),
      village_options: village_options_for(params[:fco_id], params[:ics_id]),
      farmers: target_farmers_for(
        vrp_id: params[:vrp_id],
        fco_id: params[:fco_id],
        ics_id: params[:ics_id],
        village_id: params[:village_id],
        month_name: params[:month_name],
        main_activity_name: params[:main_activity_name],
        activity_name: params[:activity_name],
        edit_target: edit_target_for_json
      )
    }
  end

  private

  def block_vrp_target_write
    return unless non_admin_vrp_login?

    redirect_to target_mappings_path, alert: "VRP target records are view only for VRP login."
  end

  def target_mapping_params
    params.require(:target_mapping).permit(
      :vrp_id,
      :fco_id,
      :ics_id,
      :village_id,
      :month_name,
      :completion_date,
      :main_activity_name,
      :activity_name,
      :target_quantity,
      afl_ids: []
    )
  end

  def editable_target
    return if params.dig(:target_mapping, :id).blank?

    visible_target_mappings.find(params.dig(:target_mapping, :id))
  end

  def target_vrps
    return Vrp.where(id: current_app_user["id"]).order(:name, :id) if non_admin_vrp_login?

    scope = Vrp.all
    scope = scope.where(status: 55) if Vrp.column_names.include?("status")
    scope = scope.where(is_active: true) if Vrp.column_names.include?("is_active")
    scope.order(:name, :id)
  end

  def assign_afl_location_names(target_mapping)
    afl = afl_scope_for_location(
      target_mapping.fco_id,
      target_mapping.ics_id,
      target_mapping.village_id,
      target_mapping.fco_name,
      target_mapping.ics_name,
      target_mapping.village_name
    ).first

    target_mapping.fco_name = target_mapping.fco_name.presence || afl&.fco
    target_mapping.ics_name = target_mapping.ics_name.presence || afl&.ics_name
    target_mapping.village_name = target_mapping.village_name.presence || afl&.village_name
  end

  def assign_target_farmers(target_mapping)
    mapped_farmer_ids = afl_ids_for_location(
      target_mapping.fco_id,
      target_mapping.ics_id,
      target_mapping.village_id,
      target_mapping.fco_name,
      target_mapping.ics_name,
      target_mapping.village_name
    )
    target_count = target_farmer_count(target_mapping)
    return false unless target_count

    selected_ids = normalized_afl_ids(target_mapping_params[:afl_ids])
    if selected_ids.blank?
      target_mapping.errors.add(:afl_ids, "select at least one farmer")
      return false
    end

    if target_count != selected_ids.size
      target_mapping.errors.add(:target_quantity, "must match selected farmers count")
      return false
    end

    if selected_ids.size > mapped_farmer_ids.size
      target_mapping.errors.add(:target_quantity, "cannot be greater than registered farmers")
      return false
    end

    invalid_ids = selected_ids - mapped_farmer_ids
    if invalid_ids.any?
      target_mapping.errors.add(:afl_ids, "include farmers outside selected village")
      return false
    end

    already_selected_ids = normalized_afl_ids(target_mapping.afl_ids)
    blocked_ids = (selected_ids - already_selected_ids) & assigned_farmer_ids_for(target_mapping)
    if blocked_ids.any?
      target_mapping.errors.add(:afl_ids, "#{blocked_ids.size} farmer already assigned for this activity")
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

  def target_farmers_for(vrp_id:, fco_id:, ics_id:, village_id:, month_name:, main_activity_name:, activity_name:, edit_target: nil)
    return [] if vrp_id.blank? || fco_id.blank? || ics_id.blank? || village_id.blank?
    return [] unless defined?(Afl) && Afl.table_exists?

    assigned_ids = assigned_farmer_ids_for_location(
      vrp_id: vrp_id,
      fco_id: fco_id,
      ics_id: ics_id,
      village_id: village_id,
      month_name: month_name,
      main_activity_name: main_activity_name,
      activity_name: activity_name,
      edit_target: edit_target
    )
    selected_ids = normalized_afl_ids(edit_target&.afl_ids)

    parsed_fco_id, parsed_fco_name = parse_location_value(fco_id)
    parsed_ics_id, parsed_ics_name = parse_location_value(ics_id)
    parsed_village_id, parsed_village_name = parse_location_value(village_id)

    afl_scope_for_location(
      parsed_fco_id,
      parsed_ics_id,
      parsed_village_id,
      parsed_fco_name,
      parsed_ics_name,
      parsed_village_name
    )
      .select(:id, :farmer_name, :father_name, :tracenet_no, :mobile_no, :khasara_no)
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

  def assigned_farmer_ids_for(target_mapping)
    assigned_farmer_ids_for_location(
      vrp_id: target_mapping.vrp_id,
      fco_id: encoded_location_value(target_mapping.fco_id, target_mapping.fco_name),
      ics_id: encoded_location_value(target_mapping.ics_id, target_mapping.ics_name),
      village_id: encoded_location_value(target_mapping.village_id, target_mapping.village_name),
      month_name: target_mapping.month_name,
      main_activity_name: target_mapping.main_activity_name,
      activity_name: target_mapping.activity_name,
      edit_target: target_mapping
    )
  end

  def assigned_farmer_ids_for_location(vrp_id:, fco_id:, ics_id:, village_id:, month_name:, main_activity_name: nil, activity_name: nil, edit_target: nil)
    return [] if main_activity_name.blank?

    parsed_fco_id, parsed_fco_name = parse_location_value(fco_id)
    parsed_ics_id, parsed_ics_name = parse_location_value(ics_id)
    parsed_village_id, parsed_village_name = parse_location_value(village_id)

    scope = TargetMapping.where(fco_id: parsed_fco_id, ics_id: parsed_ics_id, village_id: parsed_village_id)
    scope = scope.where("LOWER(TRIM(month_name)) = ?", month_name.to_s.strip.downcase) if month_name.present?
    scope = scope.where("LOWER(TRIM(main_activity_name)) = ?", main_activity_name.to_s.strip.downcase)
    scope = scope.where("LOWER(TRIM(activity_name)) = ?", activity_name.to_s.strip.downcase) if activity_name.present?
    scope = scope.where.not(id: edit_target.id) if edit_target&.persisted?
    scope.pluck(:afl_ids).flat_map { |ids| normalized_afl_ids(ids) }.uniq
  end

  def afl_ids_for_location(fco_id, ics_id, village_id, fco_name = nil, ics_name = nil, village_name = nil)
    return [] unless defined?(Afl) && Afl.table_exists?

    afl_scope_for_location(fco_id, ics_id, village_id, fco_name, ics_name, village_name).pluck(:id).map(&:to_s).uniq
  end

  def fco_options
    return [] unless defined?(Afl) && Afl.table_exists?

    Afl.where.not(fco_id: [nil, ""])
      .select(:fco_id, :fco)
      .distinct
      .order(:fco, :fco_id)
      .map { |afl| option_hash(afl.fco_id, afl.fco) }
  end

  def ics_options_for(fco_value)
    return [] if fco_value.blank? || !defined?(Afl) || !Afl.table_exists?

    fco_id, fco_name = parse_location_value(fco_value)
    scope = Afl.where(fco_id: fco_id)
    scope = scope.where(fco: fco_name) if fco_name.present?
    scope
      .where.not(ics_id: [nil, ""])
      .select(:ics_id, :ics_name)
      .distinct
      .order(:ics_name, :ics_id)
      .map { |afl| option_hash(afl.ics_id, afl.ics_name) }
  end

  def village_options_for(fco_value, ics_value)
    return [] if fco_value.blank? || ics_value.blank? || !defined?(Afl) || !Afl.table_exists?

    fco_id, fco_name = parse_location_value(fco_value)
    ics_id, ics_name = parse_location_value(ics_value)
    scope = Afl.where(fco_id: fco_id, ics_id: ics_id)
    scope = scope.where(fco: fco_name) if fco_name.present?
    scope = scope.where(ics_name: ics_name) if ics_name.present?
    scope
      .where.not(village_id: [nil, ""])
      .select(:village_id, :village_name)
      .distinct
      .order(:village_name, :village_id)
      .map { |afl| option_hash(afl.village_id, afl.village_name) }
  end

  def option_hash(value, label)
    text = [label.presence, value].compact.join(" - ")
    { value: encoded_location_value(value, label), label: text.presence || value.to_s }
  end

  def normalize_location_values(target_mapping)
    fco_id, fco_name = parse_location_value(target_mapping.fco_id)
    ics_id, ics_name = parse_location_value(target_mapping.ics_id)
    village_id, village_name = parse_location_value(target_mapping.village_id)

    target_mapping.fco_id = fco_id
    target_mapping.fco_name = fco_name
    target_mapping.ics_id = ics_id
    target_mapping.ics_name = ics_name
    target_mapping.village_id = village_id
    target_mapping.village_name = village_name
  end

  def afl_scope_for_location(fco_id, ics_id, village_id, fco_name = nil, ics_name = nil, village_name = nil)
    scope = Afl.where(fco_id: fco_id, ics_id: ics_id, village_id: village_id)
    scope = scope.where(fco: fco_name) if fco_name.present?
    scope = scope.where(ics_name: ics_name) if ics_name.present?
    scope = scope.where(village_name: village_name) if village_name.present?
    scope
  end

  def encoded_location_value(value, label)
    value = value.to_s
    label = label.to_s
    return value if label.blank?

    "#{value}||#{label}"
  end

  def parse_location_value(value)
    id, label = value.to_s.split("||", 2)
    [id.to_s, label.to_s.presence]
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

  def first_present_data(record, *keys)
    data = record.respond_to?(:data) ? record.data : record
    data ||= {}
    keys.filter_map { |key| data[key].presence }.first
  end

  def target_sub_activity_map
    return [] unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    ModuleRecord.where(module_slug: "add-vrp-activity")
      .order(created_at: :desc)
      .select { |record| record.data["status"].blank? || record.data["status"] == "Active" }
      .filter_map do |record|
        main_activity = first_present_data(record, "main_activity", "activity_group", "activity_group_name", "main_activity_name").to_s.strip
        sub_activity = first_present_data(record, "sub_activity_name", "activity_name", "vrp_activity_name").to_s.strip
        next if main_activity.blank? || sub_activity.blank?

        { main_activity: main_activity, sub_activity: sub_activity }
      end
      .uniq
  end

  def target_sub_activity_options(main_activity)
    selected_main_activity = main_activity.to_s.strip.downcase
    return [] if selected_main_activity.blank?

    target_sub_activity_map
      .select { |row| row[:main_activity].to_s.strip.downcase == selected_main_activity }
      .filter_map { |row| row[:sub_activity].presence }
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
      fco_id: encoded_location_value(target.fco_id, target.fco_name),
      ics_id: encoded_location_value(target.ics_id, target.ics_name),
      village_id: encoded_location_value(target.village_id, target.village_name),
      month_name: target.month_name.to_s,
      completion_date: target.completion_date&.strftime("%Y-%m-%d"),
      target_quantity: target.target_quantity.to_s,
      afl_ids: Array(target.afl_ids).map(&:to_s)
    }
  end
end
