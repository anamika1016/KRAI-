module Api
  module V1
    class BaseController < ActionController::API
      include AppUserPayload

      before_action :authenticate_api_user!

      private

      # Restrict mobile work lists only; dashboards and web controllers do not
      # use these helpers. A supplied old month/All must not bypass the rule.
      def current_month_lists?
        payload = current_api_user_payload || {}
        return true if payload["record_type"] == "Vrp"

        %w[role role_name stakeholder_role user_management_role person_type].any? do |key|
          payload[key].to_s.strip.match?(/\A(?:cc|cluster[ _-]*(?:incharge|coordinator))\z/i)
        end
      end

      def current_list_month
        Date.current.strftime("%B")
      end

      def current_month_created_scope(scope)
        return scope unless current_month_lists?

        start = Time.current.beginning_of_month
        scope.where(created_at: start...start.next_month)
      end

      def current_month_module_rows(rows)
        return rows unless current_month_lists?

        rows.select do |row|
          month = row[:data]["month"].to_s.strip
          if month.present?
            month.casecmp?(current_list_month)
          else
            created = row[:created_at]&.in_time_zone
            created && created.year == Date.current.year && created.month == Date.current.month
          end
        end
      end

      def authenticate_api_user!
        user = current_api_user
        return if user

        render json: { success: false, message: "Unauthorized. Please login again." }, status: :unauthorized
      end

      def current_api_user
        return @current_api_user if defined?(@current_api_user)

        @current_api_user = ApiAuthToken.find_user(bearer_token)
      end

      def current_api_user_payload
        return @current_api_user_payload if defined?(@current_api_user_payload)
        return unless current_api_user

        @current_api_user_payload = app_user_session_payload(current_api_user)
      end

      def bearer_token
        header = request.headers["Authorization"].to_s
        return header.delete_prefix("Bearer ").strip if header.start_with?("Bearer ")

        params[:token].presence
      end

      def vrp_agreement_required?(user)
        user.is_a?(Vrp) &&
          Vrp.column_names.include?("agreement_accepted_at") &&
          !user.agreement_accepted?
      end
    end
  end
end
