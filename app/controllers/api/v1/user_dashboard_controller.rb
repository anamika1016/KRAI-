module Api
  module V1
    class UserDashboardController < BaseController
      def show
        calculation_stage = "authentication"
        return render_vrp_error if current_api_user.is_a?(Vrp)

        calculation_stage = "dashboard_context"
        calculator = dashboard_calculator
        calculation_stage = "visible_vrps_and_targets"
        vrps, targets, options = filtered_scope(calculator)
        calculation_stage = "visible_bills"
        bills = filtered_bills(calculator, vrps)
        set_filtered_scope(calculator, vrps, targets, bills)

        calculation_stage = "participation_month_options"
        months = calculator.send(:dashboard_month_options_for_targets, targets)
        participation_month = selected_month(:participation_month, months, calculator, targets)
        participation_fcoc = params[:participation_fcoc].presence || calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
        calculation_stage = "participation_records"
        records = calculator.send(:dashboard_training_participation_records, month_name: participation_month, fcoc_name: participation_fcoc)
        calculation_stage = "participation_counts"
        participation = calculator.send(:training_participation_dashboard_counts,
          month_name: participation_month, fcoc_name: participation_fcoc, records: records)
        calculation_stage = "weekly_targets"
        weekly_month = selected_month(:weekly_target_month, months, calculator)
        weekly_targets = calculator.send(:dashboard_targets_for_month, targets, weekly_month)
        weekly_fcoc = params[:weekly_target_fcoc].presence || calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
        if weekly_fcoc.present?
          weekly_targets = weekly_targets.select { |target| same?(target.vrp&.fcoc, weekly_fcoc) }
        end
        weekly = calculator.send(:weekly_activity_target_status_totals, weekly_targets, week_number: selected_week)

        calculation_stage = "response_payload"
        render json: {
          success: true,
          message: "User dashboard fetched successfully.",
          dashboard_type: "user",
          user: user_payload,
          filters: applied_filters,
          filter_options: options,
          cards: card_payload(calculator, vrps, targets, bills),
          farmer_training_participation_status: participation_payload(participation, participation_month, participation_fcoc, months),
          weekly_activity_target_status: weekly_payload(weekly, weekly_month, weekly_fcoc),
          monthly_target_summary: monthly_summary(targets),
          hierarchy: hierarchy_payload(calculator),
          generated_at: Time.current.iso8601
        }, status: :ok
      rescue StandardError => error
        Rails.logger.error("User dashboard API failed at #{calculation_stage}: #{error.class}: #{error.message}\n#{error.backtrace&.first(15)&.join("\n")}")
        render json: {
          success: false,
          message: "User dashboard could not be loaded.",
          error: "dashboard_calculation_failed",
          failed_stage: calculation_stage,
          request_id: request.request_id
        }, status: :internal_server_error
      end

      private

      def render_vrp_error
        render json: { success: false, message: "This API is for User login, not Jeevika Jankar login." }, status: :forbidden
      end

      def dashboard_calculator
        ModulesController.new.tap do |controller|
          controller.request = request
          controller.instance_variable_set(:@current_app_user, current_api_user_payload)
        end
      end

      def filtered_scope(calculator)
        vrps = calculator.send(:dashboard_vrps).to_a
        targets = calculator.send(:dashboard_target_mappings).to_a
        vrps, targets = search_scope(vrps, targets)
        options = { main_activities: values(targets, :main_activity_name) }
        selected_main_activity = params[:main_activity].presence
        selected_sub_activity = params[:sub_activity].presence
        legacy_activity = params[:activity].presence
        if selected_main_activity.present?
          targets = targets.select { |target| same?(target.main_activity_name, selected_main_activity) }
        elsif legacy_activity.present?
          targets = targets.select { |target| same?(target.main_activity_name, legacy_activity) || same?(target.activity_name, legacy_activity) }
        end
        options[:sub_activities] = values(targets, :activity_name)
        targets = targets.select { |target| same?(target.activity_name, selected_sub_activity) } if selected_sub_activity.present?
        options[:activities] = (options[:main_activities] + options[:sub_activities]).uniq.sort
        if selected_main_activity.present? || selected_sub_activity.present? || legacy_activity.present?
          vrps = vrps.select { |v| targets.any? { |t| t.vrp_id == v.id } }
        end
        options[:fcos] = values(vrps, :fcoc)
        vrps, targets = filter_vrps(vrps, targets, :fcoc, params[:fcoc].presence || params[:fco])
        options[:cluster_incharges] = values(vrps, :cluster_incharge)
        vrps, targets = filter_vrps(vrps, targets, :cluster_incharge, params[:cluster_incharge])
        options[:ics_names] = targets.filter_map { |target| (target.ics_name.presence || target.ics_id).to_s.strip.presence }.uniq.sort
        selected_ics = params[:ics].presence || params[:ics_name]
        if selected_ics.present?
          targets = targets.select { |target| same?(target.ics_name.presence || target.ics_id, selected_ics) }
          vrps = vrps.select { |vrp| targets.any? { |target| target.vrp_id == vrp.id } }
        end
        options[:months] = values(targets, :month_name)
        if params[:month].present?
          targets = targets.select { |t| same?(t.month_name, params[:month]) }
          vrps = vrps.select { |v| targets.any? { |t| t.vrp_id == v.id } }
        end
        options[:post_wise_names] = values(vrps, :role)
        vrps, targets = filter_vrps(vrps, targets, :role, params[:post].presence || params[:post_wise_name])
        options[:vrps] = vrps.map { |v| { id: v.id, name: v.name, user_name: v.user_name } }
        if params[:vrp_id].present?
          vrps = vrps.select { |v| v.id.to_s == params[:vrp_id].to_s }
          targets = targets.select { |t| t.vrp_id.to_s == params[:vrp_id].to_s }
        end
        [vrps, targets, options]
      end

      def search_scope(vrps, targets)
        return [vrps, targets] if params[:search].blank?
        query = params[:search].to_s.downcase.strip
        vrps = vrps.select { |v| [v.name, v.mobile_no, v.role, v.fcoc, v.cluster_incharge].any? { |x| x.to_s.downcase.include?(query) } }
        targets = targets.select { |t| [t.vrp&.name, t.month_name, t.village_name, t.main_activity_name, t.activity_name].any? { |x| x.to_s.downcase.include?(query) } }
        [vrps, targets]
      end

      def filter_vrps(vrps, targets, attribute, selected)
        return [vrps, targets] if selected.blank?
        filtered = vrps.select { |v| same?(v.public_send(attribute), selected) }
        ids = filtered.map(&:id)
        [filtered, targets.select { |t| ids.include?(t.vrp_id) }]
      end

      def filtered_bills(calculator, vrps)
        ids = vrps.map { |v| v.id.to_s }
        filters_active = %i[search activity main_activity sub_activity fcoc fco cluster_incharge ics ics_name month post post_wise_name vrp_id].any? { |key| params[key].present? }
        records = ModuleRecord.where(module_slug: "jeevika-jankar-bill-process").to_a
          .select { |record| calculator.send(:jeevika_jankar_bill_record_visible?, record) }
        if calculator.send(:module_cluster_incharge_login?)
          records.select! do |record|
            bill_vrp = calculator.send(:jeevika_bill_vrp, record)
            bill_vrp.present? && ids.include?(bill_vrp.id.to_s)
          end
        end
        records = records
          .select { |record| ids.include?(record.data["select_vrp"].to_s) || !filters_active }
        if params[:activity].present? || params[:main_activity].present? || params[:sub_activity].present?
          records.select! do |record|
            calculator.send(:jeevika_bill_detail_rows, record).any? do |item|
              legacy_match = params[:activity].blank? || same?(item["main_activity"], params[:activity]) || same?(item["activity"], params[:activity])
              main_match = params[:main_activity].blank? || same?(item["main_activity"], params[:main_activity])
              sub_match = params[:sub_activity].blank? || same?(item["activity"], params[:sub_activity])
              legacy_match && main_match && sub_match
            end
          end
        end
        params[:month].present? ? records.select { |record| same?(record.data["bill_month"], params[:month]) } : records
      end

      def set_filtered_scope(calculator, vrps, targets, bills)
        calculator.instance_variable_set(:@filtered_vrps, vrps)
        calculator.instance_variable_set(:@filtered_targets, targets)
        calculator.instance_variable_set(:@filtered_bills, bills)
      end

      def selected_month(key, months, calculator, targets = nil)
        value = params[key].presence || calculator.send(:default_vrp_dashboard_month, months, targets)
        value.to_s.casecmp("all").zero? ? nil : value
      end

      def card_payload(calculator, vrps, targets, bills)
        hierarchy = calculator.send(:user_hierarchy_dashboard_summary)
        activities = targets.map { |t| [t.main_activity_name.to_s.downcase.strip, t.activity_name.to_s.downcase.strip] }
          .reject { |main, sub| main.blank? && sub.blank? }.uniq
        {
          level_2_users: hierarchy[:level_2_total].to_i,
          total_registered_vrp: vrps.size,
          final_approved_vrp: calculator.send(:dashboard_approved_vrps, vrps).size,
          vrp_pending_approval: calculator.send(:dashboard_pending_approval_vrps, vrps).size,
          vrp_targets_assigned: calculator.send(:dashboard_target_record_count, targets),
          activities_assigned: activities.size,
          bill_approved: bills.count { |bill| calculator.send(:dashboard_bill_approved?, bill) },
          bill_pending: bills.count { |bill| calculator.send(:dashboard_bill_pending?, bill) }
        }
      end

      def participation_payload(counts, month, fcoc, months)
        {
          selected_month: month,
          selected_fcoc: fcoc,
          month_options: months,
          registered_farmer_total: counts[:registered_farmer_total].to_i,
          total_unique_farmers: counts[:total].to_i,
          total_training_farmer: counts[:target_map_total].to_i,
          completed_target_map_total: counts[:completed_target_map_total].to_i,
          green: counts[:green].to_i,
          yellow: counts[:yellow].to_i,
          red: counts[:red].to_i,
          pending: counts[:pending].to_i
        }
      end

      def weekly_payload(totals, month, fcoc)
        {
          selected_month: month,
          selected_fcoc: fcoc,
          selected_week: selected_week,
          target_mila: number(totals[:target]),
          completed: number(totals[:completed]),
          pending: number(totals[:pending])
        }
      end

      def hierarchy_payload(calculator)
        summary = calculator.send(:user_hierarchy_dashboard_summary)
        { level_2_total: summary[:level_2_total].to_i, rows: summary[:rows] }
      end

      def monthly_summary(targets)
        targets.group_by { |t| t.month_name.presence || "Not Set" }.map do |month, rows|
          quantity = rows.sum { |row| row.target_quantity.to_f }
          { month: month, target_records: rows.size, target_quantity: number(quantity) }
        end
      end

      def user_payload
        user = current_api_user_payload
        { id: user["id"], name: user["name"], username: user["username"], role: user["role"], user_type: user["user_type"] }
      end

      def applied_filters
        %i[search activity main_activity sub_activity fcoc fco cluster_incharge ics ics_name month post post_wise_name vrp_id participation_month participation_fcoc weekly_target_month weekly_target_fcoc weekly_target_week]
          .to_h { |key| [key, params[key]] }.compact_blank
      end

      def activity_options(targets)
        targets.flat_map { |t| [t.main_activity_name, t.activity_name] }.compact_blank.uniq.sort
      end

      def selected_week
        week = params[:weekly_target_week].to_i if params[:weekly_target_week].present?
        (1..4).include?(week) ? week : nil
      end

      def values(records, attribute)
        records.filter_map { |record| record.public_send(attribute).to_s.strip.presence }.uniq.sort
      end

      def same?(left, right)
        left.to_s.strip.casecmp(right.to_s.strip).zero?
      end

      def number(value)
        value.to_f == value.to_i ? value.to_i : value.to_f.round(2)
      end
    end
  end
end
