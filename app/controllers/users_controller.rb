class UsersController < ApplicationController
  before_action :set_user, only: [:edit, :update, :destroy, :toggle_status, :set_status]
  before_action :load_form_options, only: [:new, :edit, :create, :update]

  def index
    @users = User.order(created_at: :desc)
  end

  def new
    @user = User.new(status: "Active")
  end

  def create
    @user = User.new(user_params)

    if @user.password != params.dig(:user, :confirmed_password).to_s
      flash.now[:alert] = "Password and Confirmed Password must match."
      render :new, status: :unprocessable_entity
      return
    end

    if @user.save
      redirect_to users_path, notice: "User saved successfully."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if user_params[:password].to_s != params.dig(:user, :confirmed_password).to_s
      flash.now[:alert] = "Password and Confirmed Password must match."
      render :edit, status: :unprocessable_entity
      return
    end

    if @user.update(user_params)
      refresh_current_user_session_if_needed
      redirect_to users_path, notice: "User updated successfully."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path, notice: "User deleted successfully."
  end

  def toggle_status
    next_status = @user.status == "Inactive" ? "Active" : "Inactive"
    @user.update(status: next_status)
    redirect_to users_path, notice: "Status changed to #{next_status}."
  end

  def set_status
    next_status = params[:status].presence_in(["Active", "Inactive"]) || "Active"
    @user.update(status: next_status)
    redirect_to users_path, notice: "Status changed to #{next_status}."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :stakeholder, :role, :state, :district, :block, :gram_panchayat, :village,
      :office, :full_address, :pincode, :first_name, :last_name,
      :gender, :age, :email, :password, :user_name, :mobile_no, :emergency_no,
      :user_type, :status
    )
  end

  def load_form_options
    @gender_options = ["Male", "Female", "Other"]
    @user_type_options = ["Admin", "User"]
    @status_options = ["Active", "Inactive"]
    @stakeholder_options = module_record_options("stakeholder-master", "stakeholder_name_in_english")
    @role_options = module_record_options("role-management", "role_name")
    @state_options = module_record_options("state-master", "state_name")
    @district_options = module_record_options("district-master", "district_name")
    @block_options = module_record_options("block-master", "block_name")
    @gram_panchayat_options = module_record_options("gram-panchayat-master", "gram_panchayat_name")
    @village_options = module_record_options("village-master", "village_name")
    @office_options = module_record_options("office-category-add", "category_name")
  end

  def module_record_options(module_slug, field_key)
    return [] unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    ModuleRecord
      .where(module_slug: module_slug)
      .order(created_at: :desc)
      .select { |record| record.data["status"].blank? || record.data["status"] == "Active" }
      .filter_map { |record| record.data[field_key].presence }
      .uniq
  end

  def refresh_current_user_session_if_needed
    stored_user = session[:app_user]
    return unless stored_user.present?
    return unless stored_user["id"].to_i == @user.id || stored_user["username"].to_s == @user.user_name.to_s

    refresh_app_user_session!(@user)
  end
end
