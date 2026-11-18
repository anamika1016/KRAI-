module Api
  module V1
    class CcPerformanceController < BaseController
      def show
        calculator = CcPerformanceApiCalculator.new
        calculator.request = request
        calculator.response = ActionDispatch::Response.new
        calculator.instance_variable_set(:@current_app_user, current_api_user_payload)
        unless calculator.send(:dashboard_cc_performance_visible?)
          return render json: { success: false, message: "CC performance is available to Admin, CC, FCOC and Agronomist logins." }, status: :forbidden
        end

        requested_month = params[:month].to_s.strip
        month = Date::MONTHNAMES.compact.find { |name| name.casecmp?(requested_month) }
        unless requested_month.blank? || requested_month.casecmp?("all") || month
          return render json: { success: false, message: "Use a month name such as November, or all." }, status: :unprocessable_entity
        end

        # Explicit blank means All Months, rather than the dashboard's default.
        calculator.params = ActionController::Parameters.new(
          params.permit(:fcoc, :to_name, :to, :ics, :ics_name, :vrp_id,
            :main_activity, :sub_activity, :cluster_incharge, :post, :search).to_h
            .merge("month" => month.to_s, "format" => "json"))
        result = calculator.performance
        render json: { success: true, data: result, generated_at: Time.current.iso8601 }
      end
    end
  end
end
