# Run the web dashboard only as far as its CC list branch. This keeps month,
# hierarchy, activity and active-JJ counting identical without rendering HTML.
class CcPerformanceApiCalculator < ModulesController
  def performance
    params[:cc_list] = "true"
    dashboard
    return unless @cc_dashboard_report

    {
      month: @dashboard_month_filter_value.presence || "all",
      months: Array(@filter_month_options),
      cc_target: @cc_dashboard_report.target,
      cc_achievement: @cc_dashboard_report.achievement,
      total_jj: @cc_dashboard_total_jj,
      total_opg_jj_target: @cc_dashboard_report.jj_target,
      total_opg_jj_achievement: @cc_dashboard_report.jj_achievement
    }
  end

  # The cc_list branch normally renders HTML/JSON and returns immediately.
  # The API controller owns the response; only capture the calculated values.
  def render(*)
    nil
  end
end
