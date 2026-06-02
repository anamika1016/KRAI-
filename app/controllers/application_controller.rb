class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_app_login

  helper_method :current_app_user

  private

  def require_app_login
    redirect_to login_path, alert: "Please login first." unless current_app_user
  end

  def current_app_user
    return @current_app_user if defined?(@current_app_user)

    @current_app_user = refreshed_app_user_session
  end

  def refreshed_app_user_session
    stored_user = session[:app_user]
    return unless stored_user.present?

    user = find_current_session_user(stored_user)
    return stored_user unless user

    refresh_app_user_session!(user)
  end

  def refresh_app_user_session!(user)
    refreshed_user = app_user_session_payload(user)
    session[:app_user] = refreshed_user
    @current_app_user = refreshed_user
  end

  def app_user_session_payload(user)
    data = user.respond_to?(:data) ? user.data : {}

    {
      "id" => user.id,
      "username" => user.respond_to?(:user_name) ? user.user_name : data["user_name"],
      "name" => app_user_display_name(user, data),
      "stakeholder" => user.respond_to?(:stakeholder) ? user.stakeholder : data["stakeholder"],
      "role" => user.respond_to?(:role) ? user.role : data["role"],
      "office" => user.respond_to?(:office) ? user.office : data["office"],
      "email" => user.respond_to?(:email) ? user.email : data["email"],
      "mobile_no" => user.respond_to?(:mobile_no) ? user.mobile_no : data["mobile_no"],
      "user_type" => user.respond_to?(:user_type) ? user.user_type : (data["user_type"].presence || "User")
    }
  end

  def app_user_display_name(user, data)
    return user.full_name if user.respond_to?(:full_name) && user.full_name.present?
    return user.name if user.respond_to?(:name) && user.name.present?

    [data["first_name"], data["last_name"]].compact_blank.join(" ")
  end

  def find_current_session_user(stored_user)
    if "User".safe_constantize&.table_exists?
      user = User.find_by(id: stored_user["id"])
      return user if user

      user = User.find_by(user_name: stored_user["username"])
      return user if user
    end

    if "Vrp".safe_constantize&.table_exists? && Vrp.column_names.include?("user_name")
      vrp = Vrp.find_by(id: stored_user["id"])
      return vrp if vrp

      vrp = Vrp.find_by(user_name: stored_user["username"])
      return vrp if vrp
    end

    return unless defined?(ModuleRecord) && ModuleRecord.table_exists?

    record = ModuleRecord.where(module_slug: "new-user").find_by(id: stored_user["id"])
    return record if record

    ModuleRecord
      .where(module_slug: "new-user")
      .detect { |legacy_record| legacy_record.data["user_name"].to_s == stored_user["username"].to_s }
  end
end
