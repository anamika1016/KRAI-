class VrpAgreementsController < ApplicationController
  layout :agreement_layout

  def index
    @accepted_agreements = accepted_agreement_rows
  end

  def show
    @vrp = Vrp.find_by(id: params[:id])
    unless @vrp&.agreement_accepted?
      redirect_to vrp_agreements_path, alert: "Signed agreement not found."
      return
    end

    @agreement_details = agreement_details(@vrp)
  end

  private

  def accepted_agreement_rows
    return [] unless vrp_agreement_enabled?

    Vrp.where.not(agreement_accepted_at: nil)
      .where.not(agreement_signature_data: [nil, ""])
      .order(agreement_accepted_at: :desc)
      .map do |vrp|
        {
          id: vrp.id,
          name: vrp.name.presence || vrp.user_name.presence || "-",
          village: agreement_village_name(vrp),
          mobile_no: vrp.mobile_no.presence || "-",
          accepted_at: vrp.agreement_accepted_at&.strftime("%d/%m/%Y %I:%M %p"),
          signature_present: vrp.agreement_signature_data.present?
        }
      end
  end

  def agreement_details(vrp)
    return {} unless vrp

    {
      name: vrp.name.presence || vrp.user_name.presence || "-",
      village: agreement_village_name(vrp),
      mobile_no: vrp.mobile_no.presence || "-",
      date: vrp.agreement_accepted_at&.strftime("%d/%m/%Y") || Time.zone.today.strftime("%d/%m/%Y")
    }
  end

  def agreement_village_name(vrp)
    village_id = agreement_primary_village_id(vrp)
    return "-" if village_id.blank?

    village_name = agreement_village_label(village_id)
    return village_name if village_name.present?

    village_id.to_s
  end

  def vrp_agreement_enabled?
    defined?(Vrp) && Vrp.table_exists? && Vrp.column_names.include?("agreement_accepted_at")
  end

  def agreement_layout
    action_name == "show" ? "agreement_pdf" : "application"
  end

  def agreement_primary_village_id(vrp)
    return vrp.vrp_profile.village_id if vrp.respond_to?(:vrp_profile) && vrp.vrp_profile&.village_id.present?

    Array(vrp.village_ids).map(&:to_s).reject(&:blank?).first
  end

  def agreement_village_label(village_id)
    [
      agreement_village_name_from_module_records(village_id),
      agreement_village_name_from_target_mapping(village_id),
      agreement_village_name_from_vrp_ics_mapping(village_id),
      agreement_village_name_from_afl(village_id)
    ].compact_blank.first.to_s
  end

  def agreement_village_name_from_afl(village_id)
    return unless defined?(Afl) && Afl.table_exists?

    Afl.where(village_id: village_id.to_s).order(:village_name, :id).limit(1).pick(:village_name).presence
  end

  def agreement_village_name_from_target_mapping(village_id)
    return unless defined?(TargetMapping) && TargetMapping.table_exists?

    TargetMapping.where(village_id: village_id.to_s).order(:village_name, :id).limit(1).pick(:village_name).presence
  end

  def agreement_village_name_from_vrp_ics_mapping(village_id)
    return unless defined?(VrpIcsMapping) && VrpIcsMapping.table_exists?

    VrpIcsMapping.where(village_id: village_id.to_s).order(:village_name, :id).limit(1).pick(:village_name).presence
  end

  def agreement_village_name_from_module_records(village_id)
    return unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    record = ModuleRecord.find_by(id: village_id) ||
      ModuleRecord.where(id: village_id).find_by(module_slug: "village-master") ||
      ModuleRecord.where(id: village_id).find_by(module_slug: "lg-directory-list")
    return unless record

    if record.respond_to?(:data)
      [
        record.data["village_name"],
        record.data["village"],
        record.data["name"],
        record.data["title"]
      ].compact_blank.first.presence
    end
  end
end
