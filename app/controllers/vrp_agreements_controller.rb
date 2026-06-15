class VrpAgreementsController < ApplicationController
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
    return [] unless model_ready?(:Vrp) && Vrp.column_names.include?("agreement_accepted_at")

    Vrp.where.not(agreement_accepted_at: nil)
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
    village_ids = Array(vrp.village_ids).map(&:to_s).reject(&:blank?)
    return "-" if village_ids.blank?

    if defined?(ModuleRecord) && ModuleRecord.table_exists?
      names = ModuleRecord.where(module_slug: "village-master", id: village_ids).order(created_at: :asc).filter_map do |record|
        record.data["village_name"].presence || record.data["village"].presence || record.data["name"].presence
      end
      return names.join(", ") if names.any?
    end

    village_ids.join(", ")
  end
end
