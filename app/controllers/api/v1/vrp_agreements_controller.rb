module Api
  module V1
    class VrpAgreementsController < BaseController
      skip_before_action :authenticate_api_user!, only: %i[show accept index show_record]

      AGREEMENT_TEXT = {
        intro: "I hereby confirm that I am voluntarily associated with Ploughman Agro Pvt. Ltd./ Ploughman Greensutra Pvt. Ltd. as a “Jeevika Jankar” for supporting farmer outreach and programme implementation activities in my village/ area. I understand and acknowledge that:",
        terms: [
          "My engagement is project-based and activity-based.",
          "I am not an employee, worker, or staff member of PAPL/PGPL.",
          "No employer-employee relationship is created through this engagement.",
          "I shall receive a facilitation fee/ honorarium based on approved activities carried out by me.",
          "I shall not be entitled to salary, leave, PF, ESI, gratuity, bonus, or any other employee benefits.",
          "PAPL/PGPL may discontinue my engagement at any time based on programme requirements or performance considerations.",
          "I am free to pursue my own occupation, farming, business, or other activities."
        ],
        acceptance: "I have read and understood the above conditions and agree to participate as a Jeevika Jankar."
      }.freeze

      # GET /api/v1/jeevika-jankar-agreement
      # Available to a JJ with either a bearer token or username/password. This
      # is the pre-login path for JJs whose first login is blocked pending signature.
      def show
        merge_agreement_json_body_params!
        vrp = agreement_vrp_from_credentials if agreement_credentials_present?
        vrp ||= current_api_user if current_api_user.is_a?(Vrp)
        vrp ||= selected_agreement_vrp if params[:vrp_id].present?

        # The agreement terms are public form content. Allow the client to
        # render the first-login form before obtaining a JJ token; only the
        # acceptance action requires JJ authentication.
        render json: { success: true, agreement: agreement_payload(vrp.is_a?(Vrp) ? vrp : nil) }, status: :ok
      end

      # POST /api/v1/jeevika-jankar-agreement
      # Signs in the same request after acceptance, so mobile clients can enter
      # the app without first repeating their password login.
      def accept
        merge_agreement_json_body_params!
        credentials_present = agreement_credentials_present?
        vrp = credentials_present ? agreement_vrp_from_credentials : (current_api_user if current_api_user.is_a?(Vrp))
        return render json: { success: false, message: "Invalid Jeevika Jankar username or password." }, status: :unauthorized if vrp == :invalid_credentials
        return render json: { success: false, message: "Valid Jeevika Jankar login required." }, status: :unauthorized unless vrp.is_a?(Vrp)

        signature = params[:signature_data].to_s.strip
        unless signature.match?(/\Adata:image\/(?:png|jpeg);base64,[A-Za-z0-9+\/=]+\z/)
          return render json: { success: false, message: "A valid digital signature is required." }, status: :unprocessable_entity
        end

        if vrp.agreement_accepted?
          return render json: { success: false, message: "Agreement has already been accepted." }, status: :conflict
        end

        vrp.update!(agreement_accepted_at: Time.current, agreement_signature_data: signature)
        render json: {
          success: true, message: "Agreement accepted. You can now log in.",
          token: ApiAuthToken.encode(vrp), user: app_user_session_payload(vrp),
          agreement: agreement_payload(vrp.reload)
        }, status: :ok
      rescue ActiveRecord::RecordInvalid => error
        render json: { success: false, message: "Agreement could not be saved.", errors: error.record.errors.full_messages }, status: :unprocessable_entity
      end

      # GET /api/v1/vrp-agreements
      # Mirrors the web archive: only signed, visible agreements are returned.
      def index
        merge_agreement_json_body_params!
        unless agreement_list_authorized?
          return render json: { success: false, message: "Admin or authorized office login required." }, status: :forbidden
        end

        rows = accepted_agreement_vrps
        render json: { success: true, agreements: rows.map { |vrp| agreement_list_row(vrp) }, count: rows.size,
          generated_at: Time.current.iso8601 }, status: :ok
      end

      def show_record
        merge_agreement_json_body_params!
        unless agreement_list_authorized?
          return render json: { success: false, message: "Admin or authorized office login required." }, status: :forbidden
        end

        vrp = accepted_agreement_vrps.find { |record| record.id.to_s == params[:id].to_s }
        return render json: { success: false, message: "Signed agreement not found." }, status: :not_found unless vrp

        render json: { success: true, agreement: agreement_payload(vrp) }, status: :ok
      end

      private

      def agreement_vrp_from_credentials
        login = params[:login].presence || params[:username].presence || params[:user_name].presence
        return unless login.present? || params[:password].present?

        AppUserAuthenticator.authenticate_vrp(login: login, password: params[:password]) || :invalid_credentials
      end

      def agreement_credentials_present?
        params[:username].present? || params[:user_name].present? || params[:login].present? || params[:password].present?
      end

      def merge_agreement_json_body_params!
        return unless request.body.present?

        body = request.raw_post.to_s
        return if body.blank?

        json = JSON.parse(body)
        json.each { |key, value| params[key] = value if params[key].blank? } if json.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end

      def agreement_payload(vrp)
        accepted = vrp&.agreement_accepted? && vrp.agreement_signature_data.present?
        { required: !accepted, accepted: !!accepted,
          accepted_at: vrp&.agreement_accepted_at&.iso8601, name: vrp&.name.presence || vrp&.user_name || "-",
          village: vrp ? agreement_village_name(vrp) : "-", mobile_no: vrp&.mobile_no.presence || "-",
          date: Time.zone.today.strftime("%d/%m/%Y"), intro: AGREEMENT_TEXT[:intro],
          terms: AGREEMENT_TEXT[:terms], acceptance: AGREEMENT_TEXT[:acceptance],
          signature_data: vrp&.agreement_signature_data.presence }
      end

      def accepted_agreement_vrps
        return [] unless Vrp.column_names.include?("agreement_accepted_at") && Vrp.column_names.include?("agreement_signature_data")

        visible = Vrp.all.select { |vrp| agreement_vrp_visible_to_current_user?(vrp) }.map(&:id)
        Vrp.where(id: visible).where.not(agreement_accepted_at: nil)
          .where.not(agreement_signature_data: [nil, ""]).order(agreement_accepted_at: :desc).to_a
      end

      def agreement_list_authorized?
        user = agreement_list_user
        return false unless user.present? && !user.is_a?(Vrp)

        payload = app_user_session_payload(user)
        return true if payload["user_type"].to_s.casecmp("admin").zero?

        roles = [payload["role"], payload["role_name"], payload["stakeholder_role"], payload["user_management_role"], payload["person_type"]]
          .compact_blank.map { |value| value.to_s.downcase }
        roles.any? do |role|
          role.include?("manager") || role.include?("cluster") || role.include?("agronomist") || role.include?("agricultural specialist") || role.match?(/\Afco(?:[-\s]|$)/)
        end
      end

      def agreement_vrp_visible_to_current_user?(vrp)
        payload = app_user_session_payload(agreement_list_user)
        return true if payload["user_type"].to_s.casecmp("admin").zero?

        roles = [payload["role"], payload["role_name"], payload["stakeholder_role"], payload["user_management_role"], payload["person_type"]]
          .compact_blank.map { |role| role.to_s.downcase }
        if roles.any? { |role| role.include?("manager") || role.include?("cluster") || role.include?("agronomist") || role.include?("agricultural specialist") }
          return true if roles.any? { |role| role.include?("agronomist") || role.include?("agricultural specialist") }
          current_name = payload["name"].to_s.downcase
          user = agreement_list_user
          return vrp.cluster_incharge.to_s.downcase == current_name || vrp.created_by_id.to_s == user.id.to_s
        end

        if roles.any? { |role| role.match?(/\Afco(?:[-\s]|$)/) }
          office = payload["office_name"].to_s.downcase
          return vrp.fcoc.to_s.downcase.include?(office.delete_prefix("fco-c ")) if office.present?
        end
        vrp.created_by_id.to_s == agreement_list_user.id.to_s
      end

      # The web archive uses the logged-in office account. Mobile/API clients
      # can authenticate the same account with a bearer token or credentials.
      def agreement_list_user
        return current_api_user if current_api_user.present?

        login = params[:login].presence || params[:username].presence || params[:user_name].presence
        return if login.blank? || params[:password].blank?

        AppUserAuthenticator.authenticate(login: login, password: params[:password])
      end

      def selected_agreement_vrp
        return unless agreement_list_authorized?

        Vrp.find_by(id: params[:vrp_id]).then do |vrp|
          vrp if vrp && agreement_vrp_visible_to_current_user?(vrp)
        end
      end

      def agreement_list_row(vrp)
        { id: vrp.id, name: vrp.name.presence || vrp.user_name.presence || "-", fco: vrp.fcoc.presence || "-",
          village: agreement_village_name(vrp), mobile_no: vrp.mobile_no.presence || "-",
          accepted_at: vrp.agreement_accepted_at&.strftime("%d/%m/%Y %I:%M %p"),
          signature_status: "Signed", signature_present: true,
          show_endpoint: "/api/v1/vrp-agreements/#{vrp.id}" }
      end

      def agreement_village_name(vrp)
        village_id = vrp.vrp_profile&.village_id.presence || Array(vrp.village_ids).map(&:to_s).reject(&:blank?).first
        return "-" if village_id.blank?

        village_name = ModuleRecord.find_by(id: village_id)&.data&.values_at("village_name", "village", "name", "title")&.compact_blank&.first
        village_name.presence || (TargetMapping.where(village_id: village_id.to_s).limit(1).pick(:village_name) if defined?(TargetMapping))&.presence ||
          (VrpIcsMapping.where(village_id: village_id.to_s).limit(1).pick(:village_name) if defined?(VrpIcsMapping))&.presence ||
          (Afl.where(village_id: village_id.to_s).limit(1).pick(:village_name) if defined?(Afl))&.presence || village_id.to_s
      end
    end
  end
end
