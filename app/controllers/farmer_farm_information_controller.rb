class FarmerFarmInformationController < ApplicationController
  before_action :set_farmer_farm_information, only: [:edit, :update, :destroy, :set_status]

  def index
    load_index_state
  end

  def list
    @query = params[:q].to_s.strip
    @farmer_farm_information_records = FarmerFarmInformation.search(@query).order(created_at: :desc).limit(500)
  end

  def edit
    load_index_state
    render :index
  end

  def create
    @farmer_farm_information = FarmerFarmInformation.new(farmer_farm_information_params)

    if @farmer_farm_information.save
      redirect_to farmer_farm_information_path, notice: "Farmer farm information saved successfully."
    else
      load_index_state
      flash.now[:alert] = @farmer_farm_information.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @farmer_farm_information.update(farmer_farm_information_params)
      redirect_to farmer_farm_information_path, notice: "Farmer farm information updated successfully."
    else
      load_index_state
      flash.now[:alert] = @farmer_farm_information.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @farmer_farm_information.destroy
    redirect_to list_farmer_farm_information_path, notice: "Farmer farm information deleted successfully."
  end

  def set_status
    next_status = params[:status].presence_in(["Active", "Inactive"]) || "Active"
    @farmer_farm_information.update(status: next_status)
    redirect_to list_farmer_farm_information_path, notice: "Status changed to #{next_status}."
  end

  def import
    result = FarmerFarmInformation.import(params[:file])
    total_rows = result[:imported] + result[:skipped].size
    notice = "#{result[:imported]} farmer farm information records uploaded successfully out of #{total_rows} Excel rows."
    notice += " #{result[:skipped].size} rows skipped." if result[:skipped].any?

    redirect_to list_farmer_farm_information_path, notice: notice, alert: result[:skipped].first(5).join(" | ").presence
  rescue ArgumentError => e
    redirect_to farmer_farm_information_path, alert: e.message
  end

  def export
    records = FarmerFarmInformation.search(params[:q]).order(created_at: :desc)

    send_data FarmerFarmInformation.to_csv(records),
      filename: "farmer_farm_information_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv",
      type: "text/csv"
  end

  private

  def set_farmer_farm_information
    @farmer_farm_information = FarmerFarmInformation.find(params[:id])
  end

  def load_index_state
    @query = params[:q].to_s.strip
    @edit_farmer_farm_information = FarmerFarmInformation.find_by(id: params[:edit_id]) if params[:edit_id].present?
    @farmer_farm_information ||= @edit_farmer_farm_information || FarmerFarmInformation.new
    @production_technique_options = FarmerFarmInformation::PRODUCTION_TECHNIQUES
    @certification_status_options = FarmerFarmInformation::CERTIFICATION_STATUSES
  end

  def farmer_farm_information_params
    params.require(:farmer_farm_information).permit(
      :farm_id,
      :ics_name,
      :current_crop_year,
      :season,
      :farmer_name,
      :tracenet_no,
      :father_mother_name,
      :aadhar_number,
      :farmer_address,
      :farmer_pincode,
      :farmer_contact_no,
      :farmer_state,
      :farmer_district,
      :farmer_block,
      :farmer_gram,
      :farmer_village,
      :farm_name,
      :farm_address,
      :farm_state,
      :farm_district,
      :farm_block,
      :farm_gram,
      :farm_village,
      :latitude,
      :longitude,
      :khasra_no,
      :land_details,
      :total_land,
      :no_of_farms_plots,
      :total_land_offered_for_organic_certification,
      :organic_production_started_year,
      :date_of_joining_ics,
      :present_production_technique,
      :crops_under_organic_production_area,
      :other_crops_name_area,
      :certification_status,
      :name_of_accredited_certification_body,
      :status
    )
  end
end
