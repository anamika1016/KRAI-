class SessionsController < ApplicationController
  skip_before_action :require_app_login

  def new
    redirect_to dashboard_path if current_app_user
  end

  def create
    user = find_app_user

    if user
      if vrp_agreement_required?(user)
        reset_session
        session[:pending_vrp_agreement_id] = user.id
        redirect_to vrp_agreement_path
        return
      end

      reset_session
      refresh_app_user_session!(user)
      redirect_to dashboard_path, notice: "Logged in successfully."
    else
      redirect_to login_path, alert: "Invalid username or password."
    end
  end

  def agreement
    @vrp = pending_vrp_agreement

    unless @vrp
      redirect_to login_path, alert: "Please login again to continue."
    end
  end

  def complete_agreement
    @vrp = pending_vrp_agreement

    unless @vrp
      redirect_to login_path, alert: "Please login again to continue."
      return
    end

    if params[:decision] == "agree"
      @vrp.update!(agreement_accepted_at: Time.current)
      reset_session
      refresh_app_user_session!(@vrp)
      redirect_to dashboard_path, notice: "Logged in successfully."
    else
      reset_session
      redirect_to login_path, alert: "Declaration declined. Login is allowed only after accepting the declaration."
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Logged out successfully."
  end

  private

  def pending_vrp_agreement
    return unless "Vrp".safe_constantize&.table_exists?
    return unless Vrp.column_names.include?("agreement_accepted_at")

    Vrp.where(is_active: true, is_deleted: false).find_by(id: session[:pending_vrp_agreement_id])
  end

  def vrp_agreement_required?(user)
    user.is_a?(Vrp) &&
      Vrp.column_names.include?("agreement_accepted_at") &&
      !user.agreement_accepted?
  end

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

    if "Vrp".safe_constantize&.table_exists? && Vrp.column_names.include?("user_name") && Vrp.column_names.include?("password")
      vrp = Vrp.where(is_active: true, is_deleted: false).find do |candidate|
        [candidate.user_name, candidate.email, candidate.mobile_no].compact.include?(login) &&
          candidate.password.to_s == password
      end
      return vrp if vrp
    end

    return unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    ModuleRecord.where(module_slug: "new-user").order(created_at: :desc).detect do |record|
      next false if record.data["status"] == "Inactive"

      [record.data["user_name"], record.data["email"], record.data["mobile_no"]].compact.include?(login) &&
        record.data["password"].to_s == password
    end
  end
end
