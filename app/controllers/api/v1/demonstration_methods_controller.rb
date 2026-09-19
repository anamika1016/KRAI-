module Api
  module V1
    # JSON presentation only; calculations and access scope reuse the web report.
    class DemonstrationMethodsController < BaseController
      METHODS = {
        general_training_meeting: "General Training/Meeting",
        input_demo_inm: "Input Demo INM",
        input_demo_pm: "Input Demo PM",
        ffs: "FFS"
      }.freeze
      before_action :validate_month

      def summary
        rows = report.summary.map do |row|
          metrics = METHODS.to_h do |key, label|
            [key, { target: row["#{label} Target"].to_i, achievement: row["#{label} Done"].to_i }]
          end
          { fco_id: row["fco_id"], fco_name: row["fco_name"], opg_target: row["OPG Target"].to_i,
            total: sum_metrics(metrics.values), methods: metrics }
        end
        totals = METHODS.keys.to_h do |key|
          [key, sum_metrics(rows.map { |row| row[:methods][key] })]
        end
        render json: { success: true, month: selected_month, fcos: rows,
          opg_target: rows.sum { |row| row[:opg_target] }, total: sum_metrics(totals.values), methods: totals }
      end

      def index
        rows = report.rows.map do |row|
          methods = METHODS.to_h { |key, label| [key, split_metric(row[label])] }
          { fco_id: row["fco_id"], fco_name: row["fco_name"], vrp_id: row["vrp_id"],
            vrp_name: row["VRP Name"], cluster_coordinator: row["Cluster Coordinator"],
            total: split_metric(row["OPG Target / Done"]), methods: methods,
            cc_target_status: split_metric(row["CC TARGET STATUS"]), status: row["Status"] }
        end
        if params[:q].present?
          query = params[:q].to_s.strip.downcase
          rows.select! { |row| row.values_at(:fco_name, :vrp_name, :cluster_coordinator, :vrp_id).any? { |value| value.to_s.downcase.include?(query) } }
        end
        page = [params[:page].to_i, 1].max
        per_page = params[:per_page].present? ? params[:per_page].to_i.clamp(1, 100) : 25
        render json: { success: true, month: selected_month, count: rows.size, page: page, per_page: per_page,
          records: rows.slice((page - 1) * per_page, per_page) || [] }
      end

      private

      def selected_month
        @selected_month ||= (params[:month].presence || Date.current.prev_month.strftime("%B")).to_s.strip.downcase
      end

      def validate_month
        return if Date::MONTHNAMES.compact.map(&:downcase).include?(selected_month)

        render json: { success: false, errors: ["month must be a month name, e.g. September."] }, status: :unprocessable_entity
      end

      def report
        calculator = ModulesController.new
        calculator.request = request
        calculator.instance_variable_set(:@current_app_user, current_api_user_payload)
        targets = if current_api_user.is_a?(Vrp)
          TargetMapping.where(vrp_id: current_api_user.id).to_a
        else
          calculator.send(:dashboard_target_mappings)
        end
        %i[fco_id vrp_id ics_id village_id].each do |key|
          next if params[key].blank?
          targets = targets.select { |target| target.public_send(key).to_s == params[key].to_s.strip }
        end
        DemonstrationMethodReport.new(targets: targets, month: selected_month)
      end

      def split_metric(value)
        target, achievement = value.to_s.split("/").map(&:to_i)
        { target: target || 0, achievement: achievement || 0 }
      end

      def sum_metrics(metrics)
        { target: metrics.sum { |metric| metric[:target] }, achievement: metrics.sum { |metric| metric[:achievement] } }
      end
    end
  end
end
