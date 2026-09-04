module Api
  module V1
    class JeevikaJankarDashboardController < BaseController
      def show
        if request.path.end_with?("/admin-dashboard") && !admin_dashboard_request?
          return render json: { success: false, message: "Admin login required." }, status: :forbidden
        end

        return render_admin_dashboard if admin_dashboard_request?

        vrp = current_dashboard_vrp
        return render json: { success: false, message: "Valid Jeevika Jankar login required." }, status: :unprocessable_entity unless vrp

        targets = TargetMapping.where(vrp_id: vrp.id).order(:month_name, :main_activity_name, :activity_name, :id).to_a
        months = targets.filter_map { |target| target.month_name.to_s.strip.presence }.uniq
        selected_month = filter_param(:month, :training_month) || default_month(months)
        targets = targets.select { |target| same_text?(target.month_name, selected_month) } if selected_month.present?
        progress = web_parity_progress(targets, vrp)
        assigned = progress.sum { |row| row[:assigned].to_f }
        achieved = progress.sum { |row| row[:achieved].to_f }

        render json: {
          success: true,
          message: "Jeevika Jankar dashboard fetched successfully.",
          jeevika_jankar: { id: vrp.id, name: vrp.name, user_name: vrp.user_name, mobile_no: vrp.mobile_no },
          months: months,
          selected_month: selected_month,
          cards: {
            mapped_farmers: targets.flat_map { |target| mapped_farmer_ids(target) }.uniq.size,
            mapped_villages: targets.map { |target| [target.village_id.to_s, target.village_name.to_s.downcase] }.uniq.size,
            main_activities: unique_count(targets, :main_activity_name),
            sub_activities: unique_count(targets, :activity_name),
            assigned_target: number(assigned),
            achieved_target: number(achieved),
            pending_target: number([assigned - achieved, 0].max)
          },
          target_progress: progress,
          generated_at: Time.current.iso8601
        }, status: :ok
      end

      def list
        unless admin_dashboard_request?
          return render json: { success: false, message: "Admin login required." }, status: :forbidden
        end

        payload = cached_admin_dashboard_list_payload(params[:list_type])
        return render json: { success: false, message: "Invalid dashboard list type.", available_list_types: admin_dashboard_list_catalog.keys }, status: :unprocessable_entity unless payload

        render json: {
          success: true,
          message: "#{payload[:title]} fetched successfully.",
          dashboard_type: "admin",
          list_type: params[:list_type],
          title: payload[:title],
          filters: admin_filter_payload,
          count: payload[:records].size,
          records: payload[:records]
        }, status: :ok
      end

      def farmer_training_participation
        unless admin_dashboard_request?
          return render json: { success: false, message: "Admin login required." }, status: :forbidden
        end

        response = cached_admin_dashboard_participation_payload

        render json: response, status: :ok
      end

      private

      def admin_dashboard_request?
        user = current_api_user_payload
        user["user_type"].to_s.casecmp("admin").zero? &&
          (request.path.include?("/admin-dashboard") || filter_param(:vrp_id).blank?)
      end

      def render_admin_dashboard
        dashboard = cached_admin_dashboard_summary

        render json: {
          success: true,
          message: "Admin dashboard fetched successfully.",
          dashboard_type: "admin",
          user: current_api_user_payload,
          **dashboard,
          generated_at: Time.current.iso8601
        }, status: :ok
      end

      def cached_admin_dashboard_summary
        @cached_admin_dashboard_summary ||= cache_admin_dashboard_payload("summary") { exact_admin_dashboard_data }
      end

      def cached_admin_dashboard_list_payload(list_type)
        return unless admin_dashboard_list_catalog.key?(list_type)

        cache_admin_dashboard_payload("list/#{list_type}") do
          if lightweight_admin_dashboard_list_type?(list_type)
            prepare_lightweight_admin_dashboard_context
          else
            exact_admin_dashboard_data
          end
          admin_dashboard_list_payload(list_type)
        end
      end

      def cached_admin_dashboard_participation_payload
        cache_admin_dashboard_payload("farmer-training-participation/#{normalize_participation_list_status(params[:status])}") do
          exact_admin_dashboard_data
          context = @admin_dashboard_api_context
          web = context[:web]
          status = normalize_participation_list_status(params[:status])
          records = context[:participation_records]
          population = context[:participation_population]
          trained_rows = web.send(:training_participation_farmer_rows_from_records, records)
          unique_rows = web.send(:training_afl_farmer_rows_for_participation,
            month_name: context[:participation_month], fcoc_name: filter_param(:participation_fcoc, :training_fcoc))
          status_counts = web.send(:training_participation_status_counts_from_rows, population)

          rows = case status
          when "unique" then unique_rows
          when "training_unique", "total" then trained_rows
          when "green", "yellow", "red", "pending"
            population.select { |row| row[:status] == status }
          end

          {
            success: true,
            message: "Farmer Training Participation list fetched successfully.",
            dashboard_type: "admin",
            title: participation_list_title(status),
            status: status,
            selected_month: context[:participation_month_value],
            selected_fcoc: filter_param(:participation_fcoc, :training_fcoc),
            totals: {
              total_training_farmer: web.send(:training_total_farmer_count_from_records, records),
              total_unique_farmers_distinct: unique_rows.size,
              training_unique_farmers: web.send(:training_unique_farmer_count_from_records, records),
              green: status_counts[:green].to_i,
              yellow: status_counts[:yellow].to_i,
              red: status_counts[:red].to_i,
              pending: status_counts[:pending].to_i
            },
            count: rows.size,
            farmers: rows
          }
        end
      end

      def cache_admin_dashboard_payload(suffix)
        Rails.cache.fetch(admin_dashboard_cache_key(suffix), expires_in: 10.minutes, race_condition_ttl: 30.seconds) { yield }
      rescue StandardError => error
        Rails.logger.warn("Admin dashboard cache skipped: #{error.class}: #{error.message}")
        yield
      end

      def admin_dashboard_cache_key(suffix)
        version_parts = [
          cache_table_version(TargetMapping),
          cache_table_version(Vrp),
          cache_table_version(Afl),
          cache_module_records_version(%w[
            training-form
            jeevika-jankar-bill-process
            add-vrp
            add-activity
            add-activity-group
            farmer-activity-master
            add-ics
            add-fco
            add-village
          ])
        ]
        filters = request.query_parameters.to_h.sort.to_h
        user_key = current_api_user_payload.slice("id", "user_id", "username", "user_name", "user_type").sort.to_h
        ["api-v1-admin-dashboard", suffix, user_key, filters, version_parts].to_json
      end

      def cache_table_version(model)
        Rails.cache.fetch(["api-dashboard/table-version", model.table_name], expires_in: 1.minute) do
          version = model.pick(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(MAX(id), 0)"), Arel.sql("COALESCE(EXTRACT(EPOCH FROM MAX(updated_at))::bigint, 0)"))
          "#{model.table_name}:#{version.join(":")}"
        end
      rescue StandardError
        "#{model.name}:unknown"
      end

      def cache_module_records_version(module_slugs)
        slugs = Array(module_slugs).map(&:to_s).sort
        Rails.cache.fetch(["api-dashboard/module-record-version", slugs], expires_in: 1.minute) do
          scope = ModuleRecord.where(module_slug: slugs)
          version = scope.pick(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(MAX(id), 0)"), Arel.sql("COALESCE(EXTRACT(EPOCH FROM MAX(updated_at))::bigint, 0)"))
          "module_records:#{version.join(":")}"
        end
      rescue StandardError
        "module_records:unknown"
      end

      # Uses the same private calculation methods as ModulesController#dashboard.
      # This keeps the Android JSON totals identical without changing any web action/view.
      def exact_admin_dashboard_data
        return @exact_admin_dashboard_data if defined?(@exact_admin_dashboard_data) && @exact_admin_dashboard_data

        web = ModulesController.new
        web.request = request
        web.instance_variable_set(:@current_app_user, current_api_user_payload)

        all_vrps = web.send(:dashboard_vrps).to_a
        all_targets = web.send(:dashboard_target_mappings).to_a
        preload_dashboard_associations!(all_targets)
        vrps = all_vrps.dup
        targets = all_targets.dup

        search_query = filter_param(:search)
        if search_query.present?
          query = search_query.to_s.downcase.strip
          vrps.select! do |vrp|
            [vrp.name, vrp.mobile_no, vrp.role, vrp.fcoc, vrp.cluster_incharge].any? do |value|
              value.to_s.downcase.include?(query)
            end
          end
          targets.select! do |target|
            [target.vrp&.name, target.month_name, target.village_name, target.main_activity_name, target.activity_name].any? do |value|
              value.to_s.downcase.include?(query)
            end
          end
        end

        options = {}
        options[:main_activities] = targets.map(&:main_activity_name).compact_blank.uniq.sort
        options[:activities] = options[:main_activities]
        selected_main_activity = filter_param(:main_activity) || default_farmer_activity_filter(web, options[:main_activities])
        selected_sub_activity = filter_param(:sub_activity)
        legacy_activity = filter_param(:activity)
        if selected_main_activity.present?
          normalized_main = web.send(:normalize_dashboard_text, selected_main_activity)
          main_matches = targets.select { |target| web.send(:normalize_dashboard_text, target.main_activity_name) == normalized_main }
          if main_matches.blank? && selected_sub_activity.present?
            main_matches = targets
          end
          targets = main_matches
        elsif legacy_activity.present?
          targets.select! { |target| target.main_activity_name == legacy_activity || target.activity_name == legacy_activity }
        end
        options[:sub_activities] = targets.map(&:activity_name).compact_blank.uniq.sort
        if selected_sub_activity.present?
          normalized_sub = web.send(:normalize_dashboard_text, selected_sub_activity)
          targets.select! { |target| web.send(:normalize_dashboard_text, target.activity_name) == normalized_sub }
        end
        if selected_main_activity.present? || selected_sub_activity.present? || legacy_activity.present?
          vrp_ids = id_lookup(targets, :vrp_id)
          vrps.select! { |vrp| vrp_ids.key?(vrp.id.to_s) }
        end

        selected_fcoc = filter_param(:fcoc, :fco)
        options[:fcos] = vrps.map(&:fcoc).compact_blank.uniq.sort
        if selected_fcoc.present?
          vrps.select! { |vrp| vrp.fcoc == selected_fcoc }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| target.vrp_id.present? && vrp_ids.key?(target.vrp_id.to_s) }
        end

        options[:cluster_incharges] = vrps.map(&:cluster_incharge).compact_blank.uniq.sort
        selected_cluster_incharge = filter_param(:cluster_incharge)
        if selected_cluster_incharge.present?
          vrps.select! { |vrp| web.send(:cluster_label_matches?, selected_cluster_incharge, vrp.cluster_incharge) }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| target.vrp_id.present? && vrp_ids.key?(target.vrp_id.to_s) }
        end

        options[:ics] = targets.map { |target| target.ics_name.presence || target.ics_id }.compact_blank.uniq.sort
        selected_ics = filter_param(:ics, :ics_name)
        if selected_ics.present?
          targets.select! { |target| same_text?(target.ics_name.presence || target.ics_id, selected_ics) }
          vrp_ids = id_lookup(targets, :vrp_id)
          vrps.select! { |vrp| vrp_ids.key?(vrp.id.to_s) }
        end

        options[:months] = (targets.map(&:month_name) + web.send(:month_master_month_options)).compact_blank.uniq
          .sort_by { |month| web.send(:dashboard_month_index, month) || 0 }
        selected_month = params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")
        if selected_month.present?
          targets.select! { |target| same_text?(target.month_name, selected_month) }
          vrp_ids = id_lookup(targets, :vrp_id)
          vrps.select! { |vrp| vrp_ids.key?(vrp.id.to_s) }
        end

        selected_post = filter_param(:post, :post_wise_name)
        options[:posts] = vrps.map(&:role).compact_blank.uniq.sort
        if selected_post.present?
          vrps.select! { |vrp| vrp.role == selected_post }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| target.vrp_id.present? && vrp_ids.key?(target.vrp_id.to_s) }
        end

        options[:jeevika_jankars] = vrps.map { |vrp| { id: vrp.id, name: vrp.name, user_name: vrp.user_name } }
          .uniq { |row| row[:id] }.sort_by { |row| row[:name].to_s.downcase }
        selected_vrp_filter = filter_param(:vrp_id)
        if selected_vrp_filter.present?
          selected_vrp_id = selected_vrp_filter.to_i
          vrps.select! { |vrp| vrp.id == selected_vrp_id }
          targets.select! { |target| target.vrp_id == selected_vrp_id }
        end

        web.instance_variable_set(:@filtered_vrps, vrps)
        web.instance_variable_set(:@filtered_targets, targets)
        bills = exact_dashboard_bills(web, vrps)
        web.instance_variable_set(:@filtered_bills, bills)

        months = web.send(:dashboard_month_options_for_targets, targets)
        default_month = web.send(:default_vrp_dashboard_month, months)
        participation_value = filter_param(:participation_month, :training_month) || default_month
        participation_month = participation_value == "all" ? nil : participation_value
        participation_fcoc = filter_param(:participation_fcoc, :training_fcoc)
        participation_records = web.send(:dashboard_training_participation_records, month_name: participation_month, fcoc_name: participation_fcoc)
        population = web.send(:training_participation_population_rows,
          month_name: participation_month, fcoc_name: participation_fcoc, records: participation_records)
        participation_counts = web.send(:training_participation_status_counts_from_rows, population)

        weekly_value = filter_param(:weekly_target_month) || default_month
        weekly_month = weekly_value == "all" ? nil : weekly_value
        weekly_fcoc = filter_param(:weekly_target_fcoc)
        weekly_targets = web.send(:dashboard_targets_for_month, targets, weekly_month)
        if weekly_fcoc.present?
          normalized_fcoc = web.send(:normalize_dashboard_text, weekly_fcoc)
          weekly_targets.select! { |target| web.send(:normalize_dashboard_text, target.vrp&.fcoc) == normalized_fcoc }
        end
        weekly_rows = web.send(:weekly_activity_target_farmer_status_rows,
          weekly_targets,
          month_name: weekly_month,
          fcoc_name: weekly_fcoc,
          week_number: dashboard_list_week_number)
        weekly_status_counts = web.send(:weekly_activity_target_status_counts_for_rows, weekly_rows)
        weekly_summary_totals = web.send(:dashboard_weekly_activity_summary_totals,
          weekly_targets,
          participation_counts,
          week_number: dashboard_list_week_number)
        weekly_counts = {
          target_assigned: weekly_status_counts[:total].to_i,
          completed: weekly_status_counts[:green].to_i,
          partial: weekly_status_counts[:yellow].to_i,
          pending: weekly_status_counts[:red].to_i,
          activity_target_mapping: number(weekly_summary_totals[:target]),
          activity_wise_achievement: number(weekly_summary_totals[:completed]),
          activity_wise_pending_achievement: number(weekly_summary_totals[:pending]),
          target_records: weekly_rows.size
        }

        ics_month_value = filter_param(:ics_report_month) || participation_value
        ics_month = ics_month_value == "all" ? nil : ics_month_value
        ics_targets = web.send(:training_participation_targets_for_dashboard, month_name: ics_month, fcoc_name: participation_fcoc)
        ics_records = web.send(:dashboard_training_participation_records, month_name: ics_month, fcoc_name: participation_fcoc)
        ics_options = web.send(:ics_farmer_report_options, ics_records, ics_targets)
        selected_ics = filter_param(:ics_report_ics)
        ics_rows = selected_ics ? web.send(:ics_farmer_report_rows, ics_targets, ics_records, selected_ics: selected_ics) : []
        target_progress = admin_dashboard_progress(web, targets, vrps)

        card_data = exact_admin_card_data(web, vrps, targets, all_targets, bills)
        @admin_dashboard_api_context = {
          web: web,
          vrps: vrps,
          targets: targets,
          all_targets: all_targets,
          bills: bills,
          participation_records: participation_records,
          participation_population: population,
          participation_month: participation_month,
          participation_month_value: participation_value,
          weekly_targets: weekly_targets,
          weekly_rows: weekly_rows,
          weekly_summary_totals: weekly_summary_totals,
          ics_rows: ics_rows
        }
        @exact_admin_dashboard_data = {
          filters: admin_filter_payload.merge(main_activity: selected_main_activity, sub_activity: selected_sub_activity, fcoc: selected_fcoc, month: selected_month, post: selected_post),
          filter_options: options,
          sections: card_data,
          cards: card_data.values_at(:registration, :target_assignment, :billing).reduce({}, &:merge),
          list_endpoints: admin_dashboard_list_catalog.to_h do |type, title|
            [type, { title: title, endpoint: "#{request.base_url}/api/v1/admin-dashboard/lists/#{type}" }]
          end,
          farmer_training_participation_status: {
            selected_month: participation_value,
            selected_fcoc: participation_fcoc,
            month_options: ["all"] + months,
            fco_options: options[:fcos],
            total_unique_farmers_distinct: web.send(:training_afl_farmer_rows_for_participation, month_name: participation_month, fcoc_name: participation_fcoc).size,
            total_training_farmer: web.send(:training_total_farmer_count_from_records, participation_records),
            training_unique_farmers: web.send(:training_unique_farmer_count_from_records, participation_records),
            green: participation_counts[:green].to_i,
            yellow: participation_counts[:yellow].to_i,
            red: participation_counts[:red].to_i,
            pending: participation_counts[:pending].to_i
          },
          weekly_activity_target_status: weekly_counts.merge(
            selected_month: weekly_value,
            selected_fcoc: weekly_fcoc,
            month_options: ["all"] + months,
            fco_options: options[:fcos]
          ),
          ics_wise_farmer_report: {
            selected_month: ics_month_value,
            selected_ics: selected_ics,
            month_options: ["all"] + months,
            ics_options: ics_options,
            summary: web.send(:ics_farmer_report_summary, ics_rows),
            rows: ics_rows,
            count: ics_rows.size
          },
          monthly_target_summary: monthly_progress_summary(target_progress),
          recent_target_progress: target_progress.first(100)
        }
      end

      def admin_dashboard_progress(web, targets, vrps)
        vrps_by_id = Array(vrps).index_by { |vrp| vrp.id.to_s }
        Array(targets).group_by { |target| target.vrp_id.to_s }.flat_map do |vrp_id, vrp_targets|
          vrp = vrps_by_id[vrp_id]
          next [] unless vrp

          bills = web.send(:vrp_dashboard_bills, vrp)
          web.send(:vrp_dashboard_target_progress_rows, vrp_targets, bills).map do |row|
            assigned = row[:target].to_f
            achieved = [row[:completed].to_f, assigned].min
            {
              target_mapping_id: row[:target_mapping_id],
              target_mapping_ids: row[:target_mapping_ids].presence || [row[:target_mapping_id]],
              jeevika_jankar_id: vrp.id,
              jeevika_jankar_name: vrp.name,
              month: row[:month],
              fco: row[:fco],
              ics: row[:ics],
              village: row[:village],
              main_activity: row[:main_activity],
              sub_activity: row[:activity],
              completion_date: parse_dashboard_date(row[:completion_date]),
              assigned: number(assigned),
              achieved: number(achieved),
              pending: number([assigned - achieved, 0].max),
              progress_percent: assigned.positive? ? ((achieved / assigned) * 100).round(2) : 0
            }
          end
        end
      end

      def monthly_progress_summary(progress)
        Array(progress).group_by { |row| row[:month].presence || "Not Set" }.map do |month, rows|
          {
            month: month,
            target_records: rows.size,
            target_quantity: number(rows.sum { |row| row[:assigned].to_f }),
            achieved: number(rows.sum { |row| row[:achieved].to_f }),
            pending: number(rows.sum { |row| row[:pending].to_f })
          }
        end
      end

      def exact_dashboard_bills(web, vrps)
        filtered_vrp_ids = vrps.map { |vrp| vrp.id.to_s }
        filters_active = %i[search activity main_activity sub_activity fcoc fco cluster_incharge ics ics_name month post post_wise_name vrp_id].any? { |key| filter_param(key).present? }
        scope = ModuleRecord.where(module_slug: "jeevika-jankar-bill-process")
        if filters_active
          return [] if filtered_vrp_ids.blank?

          scope = scope.where("data::jsonb ->> 'select_vrp' IN (?)", filtered_vrp_ids)
        end
        selected_bill_month = filter_param(:month)
        if selected_bill_month.present?
          scope = scope.where("LOWER(BTRIM(data::jsonb ->> 'bill_month')) = ?", selected_bill_month.to_s.strip.downcase)
        end
        bills = scope.to_a.select do |record|
          record.data.present? && (filtered_vrp_ids.include?(record.data["select_vrp"].to_s) || !filters_active)
        end
        selected_activity = filter_param(:activity)
        selected_main_activity = filter_param(:main_activity)
        selected_sub_activity = filter_param(:sub_activity)
        if selected_activity.present? || selected_main_activity.present? || selected_sub_activity.present?
          bills.select! do |record|
            web.send(:jeevika_bill_detail_rows, record).any? do |item|
              legacy_matches = selected_activity.blank? || item["main_activity"] == selected_activity || item["activity"] == selected_activity
              main_matches = selected_main_activity.blank? || web.send(:normalize_dashboard_text, item["main_activity"]) == web.send(:normalize_dashboard_text, selected_main_activity)
              sub_matches = selected_sub_activity.blank? || web.send(:normalize_dashboard_text, item["activity"]) == web.send(:normalize_dashboard_text, selected_sub_activity)
              legacy_matches && main_matches && sub_matches
            end
          end
        end
        bills
      end

      def exact_admin_card_data(web, vrps, targets, all_targets, bills)
        assigned_vrp_ids = all_targets.filter_map { |target| target.vrp_id.to_s.presence }.uniq
        activity_vrp_ids = all_targets.filter_map do |target|
          target.vrp_id.to_s.presence if target.main_activity_name.present? || target.activity_name.present?
        end.uniq
        activities = targets.map do |target|
          [web.send(:normalize_dashboard_text, target.main_activity_name), web.send(:normalize_dashboard_text, target.activity_name)]
        end.reject { |main, sub| main.blank? && sub.blank? }.uniq.size

        {
          registration: {
            total_registered: vrps.size,
            final_approved: web.send(:dashboard_approved_vrps, vrps).size,
            pending_approval: web.send(:dashboard_pending_approval_vrps, vrps).size
          },
          target_assignment: {
            target_records: web.send(:dashboard_target_record_count, targets),
            without_target: vrps.count { |vrp| !assigned_vrp_ids.include?(vrp.id.to_s) },
            activities_assigned: activities,
            without_activity: vrps.count { |vrp| !activity_vrp_ids.include?(vrp.id.to_s) }
          },
          billing: {
            level_2_users: web.send(:user_hierarchy_dashboard_summary)[:level_2_total],
            bill_approved: bills.count { |bill| web.send(:dashboard_bill_approved?, bill) },
            bill_pending: bills.count { |bill| web.send(:dashboard_bill_pending?, bill) }
          },
          fco_wise_jeevika_jankar: %w[Sausar Turekela].map do |fco_name|
            matching = vrps.select do |vrp|
              web.send(:normalize_dashboard_text, vrp.fcoc).include?(web.send(:normalize_dashboard_text, fco_name))
            end
            {
              fco: fco_name,
              male: matching.count { |vrp| web.send(:normalize_dashboard_text, vrp.gender) == "male" },
              female: matching.count { |vrp| web.send(:normalize_dashboard_text, vrp.gender) == "female" }
            }
          end
        }
      end

      def admin_dashboard_list_catalog
        {
          "total_registered" => "Total Registered Jeevika Jankar List",
          "final_approved" => "Final Approved Jeevika Jankar List",
          "pending_approval" => "Pending Approval Jeevika Jankar List",
          "target_records" => "Jeevika Jankar Target Records List",
          "total_mapped_villages" => "Total Mapped Villages List",
          "targeted_farmers" => "Targeted Farmers List",
          "total_mapped_main_activities" => "Total Mapped Main Activities List",
          "total_mapped_sub_activities" => "Total Mapped Sub-Activities List",
          "farmer_wise_achievement" => "Farmer-wise Achievement List",
          "farmer_wise_pending_achievement" => "Farmer-wise Pending Achievement List",
          "without_target" => "Jeevika Jankar Without Target List",
          "activities_assigned" => "Jeevika Jankar Activities Assigned List",
          "without_activity" => "Jeevika Jankar Without Activity List",
          "level_2_users" => "Level 2 Users List",
          "bill_approved" => "Approved Jeevika Jankar Bills List",
          "bill_pending" => "Pending Jeevika Jankar Bills List",
          "fco_sausar" => "Sausar FCO-wise Jeevika Jankar List",
          "fco_turekela" => "Turekela FCO-wise Jeevika Jankar List",
          "training_unique_farmers" => "Total Unique Farmers List",
          "training_total" => "Total Training Farmer List",
          "training_green" => "Green Training Farmers List",
          "training_yellow" => "Yellow Training Farmers List",
          "training_red" => "Red Training Farmers List",
          "training_pending" => "Pending Training Farmers List",
          "weekly_targets" => "Weekly Target List",
          "weekly_target_assigned" => "Weekly Target Assigned List",
          "weekly_completed" => "Weekly Completed List",
          "weekly_partial" => "Weekly Partial List",
          "weekly_pending" => "Weekly Pending List",
          "ics_farmers" => "ICS-wise Farmer List"
        }
      end

      def lightweight_admin_dashboard_list_type?(list_type)
        %w[
          target_records
          total_mapped_villages
          targeted_farmers
          total_mapped_main_activities
          total_mapped_sub_activities
          farmer_wise_achievement
          farmer_wise_pending_achievement
          activities_assigned
        ].include?(list_type.to_s)
      end

      def prepare_lightweight_admin_dashboard_context
        return @admin_dashboard_api_context if @admin_dashboard_api_context

        web = ModulesController.new
        web.request = request
        web.instance_variable_set(:@current_app_user, current_api_user_payload)

        all_vrps = web.send(:dashboard_vrps).to_a
        all_targets = web.send(:dashboard_target_mappings).to_a
        preload_dashboard_associations!(all_targets)
        vrps = all_vrps.dup
        targets = all_targets.dup

        search_query = filter_param(:search)
        if search_query.present?
          query = search_query.to_s.downcase.strip
          vrps.select! do |vrp|
            [vrp.name, vrp.mobile_no, vrp.role, vrp.fcoc, vrp.cluster_incharge].any? { |value| value.to_s.downcase.include?(query) }
          end
          targets.select! do |target|
            [target.vrp&.name, target.month_name, target.village_name, target.main_activity_name, target.activity_name].any? { |value| value.to_s.downcase.include?(query) }
          end
        end

        selected_main_activity = filter_param(:main_activity) || default_farmer_activity_filter(web, targets.map(&:main_activity_name).compact_blank.uniq.sort)
        selected_sub_activity = filter_param(:sub_activity)
        legacy_activity = filter_param(:activity)
        if selected_main_activity.present?
          normalized_main = web.send(:normalize_dashboard_text, selected_main_activity)
          main_matches = targets.select { |target| web.send(:normalize_dashboard_text, target.main_activity_name) == normalized_main }
          targets = main_matches.presence || targets if selected_sub_activity.present?
          targets = main_matches if main_matches.present? || selected_sub_activity.blank?
        elsif legacy_activity.present?
          targets.select! { |target| target.main_activity_name == legacy_activity || target.activity_name == legacy_activity }
        end

        if selected_sub_activity.present?
          normalized_sub = web.send(:normalize_dashboard_text, selected_sub_activity)
          targets.select! { |target| web.send(:normalize_dashboard_text, target.activity_name) == normalized_sub }
        end

        selected_fcoc = filter_param(:fcoc, :fco)
        if selected_fcoc.present?
          normalized_fcoc = web.send(:normalize_dashboard_text, selected_fcoc)
          vrps.select! { |vrp| web.send(:normalize_dashboard_text, vrp.fcoc) == normalized_fcoc }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| target.vrp_id.present? && vrp_ids.key?(target.vrp_id.to_s) }
        end

        selected_ics = filter_param(:ics, :ics_name)
        targets.select! { |target| same_text?(target.ics_name.presence || target.ics_id, selected_ics) } if selected_ics.present?

        selected_month = params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")
        targets.select! { |target| same_text?(target.month_name, selected_month) } if selected_month.present?

        selected_post = filter_param(:post, :post_wise_name)
        if selected_post.present?
          vrps.select! { |vrp| vrp.role == selected_post }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| target.vrp_id.present? && vrp_ids.key?(target.vrp_id.to_s) }
        end

        selected_vrp_filter = filter_param(:vrp_id)
        if selected_vrp_filter.present?
          selected_vrp_id = selected_vrp_filter.to_i
          vrps.select! { |vrp| vrp.id == selected_vrp_id }
          targets.select! { |target| target.vrp_id == selected_vrp_id }
        end

        months = web.send(:dashboard_month_options_for_targets, targets)
        default_month = web.send(:default_vrp_dashboard_month, months)
        participation_value = filter_param(:participation_month, :training_month) || default_month
        participation_month = participation_value == "all" ? nil : participation_value

        @admin_dashboard_api_context = {
          web: web,
          vrps: vrps,
          targets: targets,
          all_targets: all_targets,
          bills: [],
          participation_month: participation_month,
          participation_month_value: participation_value
        }
      end

      def admin_dashboard_list_payload(list_type)
        context = @admin_dashboard_api_context
        return unless context

        web = context[:web]
        vrps = context[:vrps]
        targets = context[:targets]
        all_targets = context[:all_targets]
        bills = context[:bills]
        assigned_ids = all_targets.filter_map { |target| target.vrp_id.to_s.presence }.uniq
        activity_ids = all_targets.filter_map do |target|
          target.vrp_id.to_s.presence if target.main_activity_name.present? || target.activity_name.present?
        end.uniq

        records = case list_type
        when "total_registered"
          vrps.map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "final_approved"
          web.send(:dashboard_approved_vrps, vrps).map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "pending_approval"
          web.send(:dashboard_pending_approval_vrps, vrps).map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "target_records"
          grouped_admin_targets(targets)
        when "total_mapped_villages"
          grouped_admin_villages(targets)
        when "targeted_farmers"
          web.send(:training_afl_farmer_rows_for_participation,
            month_name: dashboard_list_participation_month, fcoc_name: filter_param(:participation_fcoc, :training_fcoc))
        when "total_mapped_main_activities"
          grouped_admin_activities(targets, :main_activity_name, "Main Activity")
        when "total_mapped_sub_activities"
          grouped_admin_activities(targets, :activity_name, "Sub Activity")
        when "farmer_wise_target_mapping"
          dashboard_participation_target_map_rows(web, context)
        when "farmer_wise_achievement"
          dashboard_participation_target_map_rows(web, context).select { |row| row[:completed_activity_count].to_i.positive? }
        when "farmer_wise_pending_achievement"
          dashboard_participation_target_map_rows(web, context).select { |row| row[:completed_activity_count].to_i < row[:assigned_activity_count].to_i }
        when "without_target"
          vrps.reject { |vrp| assigned_ids.include?(vrp.id.to_s) }.map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "activities_assigned"
          targets.select { |target| target.main_activity_name.present? || target.activity_name.present? }.map { |target| admin_target_list_row(target) }
        when "without_activity"
          vrps.reject { |vrp| activity_ids.include?(vrp.id.to_s) }.map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "level_2_users"
          web.send(:user_hierarchy_dashboard_summary)[:rows].map.with_index do |row, index|
            { id: index + 1, name: row[0], reports_to: row[1], level: row[2], assignment_status: "Mapped" }
          end
        when "bill_approved"
          bills.select { |bill| web.send(:dashboard_bill_approved?, bill) }.map { |bill| admin_bill_list_row(bill, vrps) }
        when "bill_pending"
          bills.select { |bill| web.send(:dashboard_bill_pending?, bill) }.map { |bill| admin_bill_list_row(bill, vrps) }
        when "fco_sausar", "fco_turekela"
          fco_name = list_type.delete_prefix("fco_")
          vrps.select { |vrp| web.send(:normalize_dashboard_text, vrp.fcoc).include?(fco_name) }
            .map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "training_unique_farmers"
          web.send(:training_afl_farmer_rows_for_participation,
            month_name: dashboard_list_participation_month, fcoc_name: filter_param(:participation_fcoc, :training_fcoc))
        when "training_total"
          web.send(:training_participation_farmer_rows_from_records, context[:participation_records])
        when "training_green", "training_yellow", "training_red", "training_pending"
          status = list_type.delete_prefix("training_")
          context[:participation_population].select { |row| row[:status] == status }
        when "weekly_targets", "weekly_target_assigned", "activity_wise_target_mapping"
          context[:weekly_rows]
        when "weekly_completed", "activity_wise_achievement"
          context[:weekly_rows].select { |row| row[:status_class].to_s == "green" }
        when "weekly_partial"
          context[:weekly_rows].select { |row| row[:status_class].to_s == "yellow" }
        when "weekly_pending", "activity_wise_pending_achievement"
          context[:weekly_rows].select { |row| row[:status_class].to_s == "red" }
        when "ics_farmers"
          context[:ics_rows]
        end
        return unless records

        { title: admin_dashboard_list_catalog.fetch(list_type), records: records }
      end

      def admin_vrp_list_row(vrp, assigned_ids, activity_ids)
        target_assigned = assigned_ids.include?(vrp.id.to_s)
        activity_assigned = activity_ids.include?(vrp.id.to_s)
        {
          id: vrp.id,
          name: vrp.name,
          user_name: vrp.user_name,
          mobile_no: vrp.mobile_no,
          gender: vrp.gender,
          role: vrp.role,
          fco: vrp.fcoc,
          cluster_incharge: vrp.cluster_incharge,
          approval_status: vrp.status,
          target_assigned: target_assigned,
          target_assignment_status: target_assigned ? "Assigned" : "Not Assigned",
          activity_assigned: activity_assigned,
          activity_assignment_status: activity_assigned ? "Assigned" : "Not Assigned"
        }
      end

      def admin_target_list_row(target)
        {
          id: target.id,
          jeevika_jankar_id: target.vrp_id,
          name: target.vrp&.name,
          assignment_status: "Assigned",
          month: target.month_name,
          fco: target.vrp&.fcoc.presence || target.fco_name.presence || target.fco_id,
          ics: target.ics_name.presence || target.ics_id,
          village: target.village_name.presence || target.village_id,
          main_activity: target.main_activity_name,
          sub_activity: target.activity_name,
          target_quantity: number(target.target_quantity.to_f)
        }
      end

      def grouped_admin_targets(targets)
        Array(targets).group_by do |target|
          [
            target.vrp_id,
            target.fco_name.presence || target.fco_id,
            target.ics_name.presence || target.ics_id,
            target.village_name.presence || target.village_id,
            target.month_name,
            target.completion_date,
            target.opg_training_target.to_s,
            target.week_wise_opg_target.to_s,
            target.input_demo_inm_target.to_s,
            target.input_demo_pm_target.to_s,
            target.ffs_target.to_s,
            Array(target.afl_ids).map(&:to_s).reject(&:blank?).sort
          ]
        end.values.map do |rows|
          first = rows.first
          admin_target_list_row(first).merge(
            target_mapping_ids: rows.map(&:id),
            main_activities: rows.map(&:main_activity_name).compact_blank.uniq,
            sub_activities: rows.map(&:activity_name).compact_blank.uniq
          )
        end
      end

      def grouped_admin_villages(targets)
        Array(targets).group_by { |target| [target.village_id.to_s, target.village_name.to_s.downcase.strip] }
          .values.map.with_index(1) do |rows, index|
            first = rows.first
            {
              id: first.village_id.presence || index,
              name: first.village_name.presence || first.village_id,
              assignment_status: "Mapped",
              target_records: rows.size,
              target_quantity: number(rows.sum { |row| row.target_quantity.to_f }),
              fcos: rows.filter_map { |row| row.vrp&.fcoc.presence || row.fco_name.presence || row.fco_id }.uniq,
              ics_names: rows.filter_map { |row| row.ics_name.presence || row.ics_id }.uniq,
              months: rows.filter_map(&:month_name).uniq
            }
          end
      end

      def grouped_admin_activities(targets, attribute, label)
        Array(targets).group_by { |target| target.public_send(attribute).to_s.downcase.strip }
          .reject { |name, _rows| name.blank? }
          .values.map.with_index(1) do |rows, index|
            first = rows.first
            name = first.public_send(attribute)
            {
              id: index,
              name: name,
              activity_type: label,
              assignment_status: "Mapped",
              target_records: rows.size,
              target_quantity: number(rows.sum { |row| row.target_quantity.to_f }),
              jeevika_jankar_count: rows.filter_map(&:vrp_id).uniq.size,
              farmer_count: rows.flat_map { |row| mapped_farmer_ids(row) }.uniq.size,
              months: rows.filter_map(&:month_name).uniq
            }
          end
      end

      def dashboard_participation_target_map_rows(web, context)
        return context[:participation_target_map_rows] if context[:participation_target_map_rows]

        targets = web.send(:training_participation_targets_for_dashboard,
          month_name: dashboard_list_participation_month,
          fcoc_name: filter_param(:participation_fcoc, :training_fcoc))
        context[:participation_target_map_rows] = web.send(:training_participation_target_map_rows, targets, month_name: dashboard_list_participation_month)
      end

      def admin_bill_list_row(bill, vrps)
        vrp = vrps.find { |record| record.id.to_s == bill.data["select_vrp"].to_s }
        {
          id: bill.id,
          jeevika_jankar_id: bill.data["select_vrp"],
          name: bill.data["jeevika_jankar_name"].presence || bill.data["vrp_name"].presence || vrp&.name,
          status: bill.data["status"],
          assignment_status: bill.data["status"],
          bill_month: bill.data["bill_month"],
          financial_year: bill.data["financial_year"],
          total_payment: number(bill.data["total_payment"].to_f)
        }
      end

      def dashboard_list_participation_month
        value = filter_param(:participation_month, :training_month) || @admin_dashboard_api_context&.dig(:participation_month)
        value == "all" ? nil : value
      end

      def normalize_participation_list_status(value)
        status = value.to_s.downcase.presence || "unique"
        aliases = {
          "total_unique" => "unique",
          "training" => "total",
          "training_total" => "total",
          "training_unique" => "training_unique"
        }
        status = aliases.fetch(status, status)
        %w[unique total training_unique green yellow red pending].include?(status) ? status : "unique"
      end

      def participation_list_title(status)
        {
          "unique" => "Total Unique Farmers Farmer List",
          "total" => "Total Training Farmer List",
          "training_unique" => "Training Unique Farmers List",
          "green" => "Green Farmer List",
          "yellow" => "Yellow Farmer List",
          "red" => "Red Farmer List",
          "pending" => "Pending Farmer List"
        }.fetch(status)
      end

      def dashboard_list_week_number
        week = params[:weekly_target_week].to_i if params[:weekly_target_week].present?
        (1..4).include?(week) ? week : nil
      end

      def admin_filter_options(vrps, targets)
        {
          activities: targets.filter_map { |target| target.main_activity_name.to_s.strip.presence }.uniq.sort,
          fcos: vrps.filter_map { |vrp| vrp.fcoc.to_s.strip.presence }.uniq.sort,
          cluster_incharges: vrps.filter_map { |vrp| vrp.cluster_incharge.to_s.strip.presence }.uniq.sort,
          months: (web.send(:month_master_month_options) + targets.filter_map { |target| target.month_name.to_s.strip.presence })
            .uniq { |month| web.send(:normalize_dashboard_text, month) }
            .sort_by { |month| [web.send(:dashboard_month_index, month), month] },
          post_wise_names: vrps.filter_map { |vrp| vrp.role.to_s.strip.presence }.uniq.sort,
          jeevika_jankars: vrps.map { |vrp| { id: vrp.id, name: vrp.name, user_name: vrp.user_name } }
        }
      end

      def filter_admin_vrps(vrps)
        vrps.select do |vrp|
          filter_value_matches?(vrp.fcoc, filter_param(:fco, :fcoc)) &&
            filter_value_matches?(vrp.cluster_incharge, filter_param(:cluster_incharge)) &&
            filter_value_matches?(vrp.role, filter_param(:post_wise_name, :post)) &&
            (filter_param(:vrp_id).blank? || vrp.id.to_s == filter_param(:vrp_id).to_s)
        end
      end

      def filter_admin_targets(targets)
        targets.select do |target|
          filter_value_matches?(target.month_name, filter_param(:month)) &&
            filter_value_matches?(target.main_activity_name, filter_param(:activity, :main_activity)) &&
            filter_value_matches?(target.activity_name, filter_param(:sub_activity))
        end
      end

      def admin_vrp_filters_present?
        %i[fco cluster_incharge post_wise_name vrp_id].any? { |key| filter_param(key).present? }
      end

      def admin_filter_payload
        {
          activity: filter_param(:activity, :main_activity),
          fco: filter_param(:fco, :fcoc),
          cluster_incharge: filter_param(:cluster_incharge),
          month: filter_param(:month),
          post_wise_name: filter_param(:post_wise_name, :post),
          vrp_id: filter_param(:vrp_id),
          sub_activity: filter_param(:sub_activity)
        }.compact
      end

      def default_farmer_activity_filter(web, activity_options)
        Array(activity_options).find do |activity|
          %w[Farmer\ Activity Farmers'\ Training Farmers\ Training].any? do |label|
            web.send(:normalize_dashboard_text, activity) == web.send(:normalize_dashboard_text, label)
          end
        end
      end

      def filter_value_matches?(actual, selected)
        selected.blank? || same_text?(actual, selected)
      end

      def filter_param(*keys)
        keys.each do |key|
          value = params[key].to_s.strip
          next if all_filter_value?(value)

          return value if value.present?
        end
        nil
      end

      def all_filter_value?(value)
        normalized = value.to_s.strip.downcase
        normalized.blank? || normalized == "all" || normalized.start_with?("all ")
      end

      def preload_dashboard_associations!(targets)
        ActiveRecord::Associations::Preloader.new(records: targets, associations: :vrp).call if targets.any?
      rescue StandardError => error
        Rails.logger.debug("Admin dashboard preload skipped: #{error.class}: #{error.message}")
      end

      def id_lookup(records, attribute = :id)
        records.each_with_object({}) { |record, lookup| lookup[record.public_send(attribute).to_s] = true }
      end

      def training_participation_status(targets)
        farmer_ids = targets.flat_map { |target| mapped_farmer_ids(target) }.uniq
        attendance = Hash.new(0)
        ModuleRecord.where(module_slug: "training-form").select { |record| active_record?(record) }.each do |record|
          Array(record.data["selected_farmer_ids"]).map(&:to_s).uniq.each { |farmer_id| attendance[farmer_id] += 1 }
        end
        green = farmer_ids.count { |id| attendance[id] >= 3 }
        yellow = farmer_ids.count { |id| attendance[id].between?(1, 2) }
        untrained = farmer_ids.select { |id| attendance[id].zero? }
        closed_target = targets.any? { |target| target.completion_date.present? && target.completion_date < Date.current }
        red = closed_target ? untrained.size : 0
        pending = closed_target ? 0 : untrained.size
        { total_training_farmers: farmer_ids.size, green: green, yellow: yellow, red: red, pending: pending }
      end

      def target_dashboard_payload(targets)
        sub_activities = targets.filter_map { |target| target.activity_name.to_s.strip.presence }.uniq.sort
        {
          selected_month: filter_param(:month),
          selected_sub_activity: filter_param(:sub_activity),
          sub_activity_options: sub_activities,
          rows: targets.map { |target| progress_payload(target) }
        }
      end

      def weekly_target_status(progress)
        percentages = progress.map { |row| row[:progress_percent].to_f }
        {
          total_targets: progress.size,
          green: percentages.count { |value| value >= 100 },
          yellow: percentages.count { |value| value >= 75 && value < 100 },
          red: percentages.count { |value| value < 75 }
        }
      end

      def monthly_target_summary(targets)
        targets.group_by { |target| target.month_name.presence || "Not Set" }.map do |month, rows|
          {
            month: month,
            target_records: rows.size,
            target_quantity: number(rows.sum { |target| target.target_quantity.to_f })
          }
        end
      end

      def approved_bill?(bill)
        status = bill.data["approval_status"].presence || bill.data["status"]
        status.to_s.downcase.include?("approved") && !status.to_s.downcase.include?("pending")
      end

      def current_dashboard_vrp
        user = current_api_user_payload
        return Vrp.find_by(id: user["id"]) if user["record_type"] == "Vrp"
        selected_vrp_id = filter_param(:vrp_id)
        return Vrp.find_by(id: selected_vrp_id) if user["user_type"].to_s.casecmp("admin").zero? && selected_vrp_id.present?
      end

      def default_month(months)
        previous = Date.current.prev_month.strftime("%B")
        months.find { |month| same_text?(month, previous) } || months.last
      end

      def unique_count(targets, field)
        targets.filter_map { |target| target.public_send(field).to_s.downcase.strip.presence }.uniq.size
      end

      def progress_payload(target)
        assigned = target.target_quantity.to_f
        achieved = [target_achievement(target), assigned].min
        {
          target_mapping_id: target.id.to_s,
          month: target.month_name,
          fco: target.fco_name.presence || target.fco_id,
          ics: target.ics_name.presence || target.ics_id,
          village: target.village_name.presence || target.village_id,
          main_activity: target.main_activity_name,
          sub_activity: target.activity_name,
          completion_date: target.completion_date&.iso8601,
          assigned: number(assigned),
          achieved: number(achieved),
          pending: number([assigned - achieved, 0].max),
          progress_percent: assigned.positive? ? ((achieved / assigned) * 100).round(2) : 0
        }
      end

      # Keep the mobile dashboard totals identical to the existing VRP web dashboard.
      # The web calculation handles Main Activity Type, farmer/activity/month matching,
      # completion deadlines, approved Other targets, and the bill fallback.
      def web_parity_progress(targets, vrp)
        calculator = ModulesController.new
        bills = calculator.send(:vrp_dashboard_bills, vrp)
        rows = calculator.send(:vrp_dashboard_target_progress_rows, targets, bills)

        rows.map do |row|
          assigned = row[:target].to_f
          achieved = [row[:completed].to_f, assigned].min
          {
            target_mapping_id: row[:target_mapping_id],
            month: row[:month],
            fco: row[:fco],
            ics: row[:ics],
            village: row[:village],
            main_activity: row[:main_activity],
            sub_activity: row[:activity],
            completion_date: parse_dashboard_date(row[:completion_date]),
            assigned: number(assigned),
            achieved: number(achieved),
            pending: number([assigned - achieved, 0].max),
            progress_percent: assigned.positive? ? ((achieved / assigned) * 100).round(2) : 0
          }
        end
      end

      def parse_dashboard_date(value)
        return if value.blank? || value == "-"

        Date.strptime(value.to_s, "%d-%m-%Y").iso8601
      rescue ArgumentError
        value
      end

      def target_achievement(target)
        records = ModuleRecord.where(module_slug: %w[training-form seed-distribution-target papl360-target add-farmer-form])
          .select { |record| record.data["target_mapping_id"].to_s == target.id.to_s && active_record?(record) }
        training_ids = records.select { |record| record.module_slug == "training-form" }
          .flat_map { |record| Array(record.data["selected_farmer_ids"]).map(&:to_s) }.reject(&:blank?).uniq
        other = records.reject { |record| record.module_slug == "training-form" }.sum do |record|
          (record.data["achievement"].presence || record.data["no_farmer"].presence || Array(record.data["selected_farmer_ids"]).size).to_f
        end
        training_ids.size + other
      end

      def mapped_farmer_ids(target)
        ids = Array(target.afl_ids).map(&:to_s).reject(&:blank?).uniq
        return ids if ids.any?

        VrpIcsMapping.where(vrp_id: target.vrp_id).select do |mapping|
          location_match?(mapping.fco_id, mapping.fco_name, target.fco_id, target.fco_name) &&
            location_match?(mapping.ics_id, mapping.ics_name, target.ics_id, target.ics_name) &&
            location_match?(mapping.village_id, mapping.village_name, target.village_id, target.village_name)
        end.flat_map { |mapping| Array(mapping.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
      end

      def location_match?(left_id, left_name, right_id, right_name)
        left = [left_id, left_name].compact_blank.map { |value| value.to_s.strip.downcase }
        right = [right_id, right_name].compact_blank.map { |value| value.to_s.strip.downcase }
        (left & right).any?
      end

      def active_record?(record)
        status = record.data["status"].to_s.strip.downcase
        !%w[inactive rejected returned deleted].include?(status) && !record.data["is_deleted"].to_s.casecmp("true").zero?
      end

      def same_text?(left, right)
        left.to_s.strip.casecmp(right.to_s.strip).zero?
      end

      def number(value)
        value.to_f == value.to_i ? value.to_i : value.to_f.round(2)
      end
    end
  end
end
