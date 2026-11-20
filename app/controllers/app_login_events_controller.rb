class AppLoginEventsController < ApplicationController
  # Who signed in from the mobile app -- Jeevika Jankars and users alike. The
  # filter opens on today, so the page answers "who used the app today" without
  # anything being selected, and Month / All widen the same window.
  def index
    @period = params[:period].to_s.presence_in(AppLoginEvent::PERIODS) || "day"
    @selected_date = parsed_date(params[:date]) || Date.current
    @selected_month = parsed_month(params[:month]) || @selected_date.beginning_of_month
    @period_date = @period == "month" ? @selected_month : @selected_date

    @login_events = AppLoginEvent.for_period(@period, @period_date).newest_first.to_a
    @login_count = @login_events.size
    @jj_login_count = @login_events.count { |event| event.account_type == "Vrp" }
    @user_login_count = @login_count - @jj_login_count
    # One person opening the app five times is five logins but one person, and
    # the cards say both so the numbers cannot be misread.
    @unique_people_count = @login_events.map { |event| [event.account_type, event.account_id] }.uniq.size
    @first_recorded_on = AppLoginEvent.minimum(:logged_in_at)&.to_date

    respond_to do |format|
      format.html
      format.xlsx do
        send_xlsx(
          headers: ["Name", "Username", "Type", "Role", "Login Date", "Login Time"],
          rows: @login_events.map { |event| export_row(event) },
          filename: "app-login-detail-#{export_suffix}.xlsx",
          sheet_name: "App Login Detail"
        )
      end
    end
  end

  private

  def export_row(event)
    [
      event.display_name,
      event.user_name,
      event.account_type == "Vrp" ? "Jeevika Jankar" : "User",
      event.role,
      event.logged_in_at&.strftime("%d %b %Y"),
      event.logged_in_at&.strftime("%I:%M %p")
    ]
  end

  # The file name says which window it covers, so a saved export is never
  # mistaken for a different period later.
  def export_suffix
    case @period
    when "month" then @selected_month.strftime("%Y-%m")
    when "all" then "all"
    else @selected_date.strftime("%Y-%m-%d")
    end
  end

  # An unreadable or blank value falls back rather than erroring.
  def parsed_date(value)
    text = value.to_s.strip
    return nil if text.blank?

    Date.parse(text)
  rescue ArgumentError, TypeError
    nil
  end

  def parsed_month(value)
    text = value.to_s.strip
    return nil if text.blank?

    Date.parse("#{text}-01")
  rescue ArgumentError, TypeError
    nil
  end

  def period_label
    case @period
    when "month" then @selected_month.strftime("%B %Y")
    when "all" then "All Logins"
    else @selected_date.strftime("%d %B %Y")
    end
  end
  helper_method :period_label
end
