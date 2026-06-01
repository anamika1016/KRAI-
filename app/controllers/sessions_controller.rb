class SessionsController < ApplicationController
  skip_before_action :require_app_login

  def new
    redirect_to dashboard_path if current_app_user
  end

  def create
    user = find_app_user

    if user
      refresh_app_user_session!(user)
      redirect_to dashboard_path, notice: "Logged in successfully."
    else
      redirect_to login_path, alert: "Invalid username or password."
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Logged out successfully."
  end

  private

  def find_app_user
    login = params[:login].presence || params[:email].presence
    password = params[:password].to_s
    return if login.blank? || password.blank?

    if "User".safe_constantize&.table_exists?
      user = User.where.not(status: "Inactive").find do |candidate|
        [candidate.user_name, candidate.email, candidate.mobile_no].compact.include?(login) &&
          candidate.password.to_s == password
      end
      return user if user
    end

    return unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    ModuleRecord.where(module_slug: "new-user").order(created_at: :desc).detect do |record|
      next false if record.data["status"] == "Inactive"

      [record.data["user_name"], record.data["email"], record.data["mobile_no"]].compact.include?(login) &&
        record.data["password"].to_s == password
    end
  end
end
