module Api
  module V1
    class UserDashboardController < JeevikaJankarDashboardController
      def show
        return render_vrp_error if current_api_user.is_a?(Vrp)

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = cached_user_dashboard_response
        duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
        self.response.set_header("Server-Timing", "dashboard;dur=#{duration}")
        response = response.merge(meta: { server_processing_ms: duration, cache_hit: !!@dashboard_cache_hit })
        render json: response, status: response[:success] ? :ok : :internal_server_error
      end

      # Lightweight mobile landing page: no weekly farmer lists, Other SQL,
      # billing, hierarchy or CC/JJ work-status reports.
      def boxes
        return render_vrp_error if current_api_user.is_a?(Vrp)

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        calculator = dashboard_calculator
        vrps, targets, options = filtered_scope(calculator)
        summary_vrps, summary_targets = summary_scope(calculator)
        set_filtered_scope(calculator, vrps, targets, [], summary_vrps: summary_vrps, summary_targets: summary_targets)
        month = selected_month(:participation_month, [], calculator, targets)
        fcoc = filter_param(:participation_fcoc) || calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
        # Counts use the same SQL path as the web cards; loading every training
        # record here only delays the mobile landing page.
        counts = calculator.send(:training_participation_dashboard_counts, month_name: month, fcoc_name: fcoc, records: [])
        sections = OfficeDashboardSections.new(calculator: calculator, targets: targets,
          participation: counts, month: month, fcoc: fcoc).sections(only: :primary)
        duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
        response.set_header("Server-Timing", "dashboard;dur=#{duration}")
        render json: { success: true, dashboard_type: "user", user: user_payload,
          filters: applied_filters, filter_options: options, sections: sections,
          meta: { server_processing_ms: duration }, generated_at: Time.current.iso8601 }
      end

      # Scoped drill-down for CC, Agronomist, FCO and other office users.
      # It deliberately uses only the VRPs and targets already visible to this login.
      def list
        return render_vrp_error if current_api_user.is_a?(Vrp)

        payload = user_dashboard_list_payload(params[:list_type])
        return render json: { success: false, message: "Invalid dashboard list type.", available_list_types: user_dashboard_list_catalog.keys }, status: :unprocessable_entity unless payload

        render json: {
          success: true,
          message: "#{payload[:title]} fetched successfully.",
          dashboard_type: "user",
          list_type: params[:list_type],
          title: payload[:title],
          filters: applied_filters,
          count: payload[:records].size,
          records: payload[:records],
          generated_at: Time.current.iso8601
        }
      end

      def export
        return render_vrp_error if current_api_user.is_a?(Vrp)

        payload = user_dashboard_list_payload(params[:list_type])
        return render json: { success: false, message: "Invalid dashboard list type.", available_list_types: user_dashboard_list_catalog.keys }, status: :unprocessable_entity unless payload

        send_dashboard_list_export(payload)
      end

      def widget
        return render_vrp_error if current_api_user.is_a?(Vrp)

        config = user_dashboard_widget_catalog[params[:widget]]
        return render json: { success: false, message: "Invalid dashboard widget.", available_widgets: user_dashboard_widget_catalog.keys }, status: :unprocessable_entity unless config

        if report_widget?(params[:widget])
          return render json: report_widget_response(params[:widget], config, "user")
        end

        dashboard = cached_user_dashboard_response
        return render json: dashboard, status: :internal_server_error unless dashboard[:success]

        value = config[:section_card] ? dashboard[:sections].flat_map { |section| section[:cards] }.find { |card| card[:key] == config[:section_card] }&.dig(:value) : config[:path].reduce(dashboard) { |data, key| data.respond_to?(:[]) ? data[key] || data[key.to_s] : nil }
        render json: { success: true, dashboard_type: "user", widget: params[:widget], heading: config[:heading], value: value, filters: dashboard[:filters], generated_at: Time.current.iso8601 }
      end

      def filters
        return render_vrp_error if current_api_user.is_a?(Vrp)

        calculator = dashboard_calculator
        render json: mobile_dashboard_filter_options(calculator.send(:dashboard_target_mappings), calculator).merge(
          success: true, dashboard_type: "user", generated_at: Time.current.iso8601
        )
      end

      def configuration
        return render_vrp_error if current_api_user.is_a?(Vrp)

        render json: {
          success: true, dashboard_type: "user", user: user_payload,
          endpoint: "/api/v1/user-dashboard", boxes_endpoint: "/api/v1/user-dashboard/boxes", filters_endpoint: "/api/v1/user-dashboard/filters",
          widgets: user_dashboard_widget_catalog.map { |key, config|
            { key: key, heading: config[:heading], endpoint: "/api/v1/user-dashboard/widgets/#{key}" }
          },
          lists: user_dashboard_list_catalog.map { |key, title|
            { key: key, title: title, endpoint: "/api/v1/user-dashboard/lists/#{key}",
              export_endpoint: "/api/v1/user-dashboard/lists/#{key}/export" }
          }
        }
      end

      private

      def office_ics_report(calculator, targets, records, month, fcoc)
        if params.key?(:ics_report_month)
          month = filter_param(:ics_report_month)
          records = calculator.send(:dashboard_training_participation_records, month_name: month, fcoc_name: fcoc)
          targets = calculator.send(:training_participation_targets_for_dashboard, month_name: month, fcoc_name: fcoc)
        end
        selected = filter_param(:ics_report_ics)
        rows = selected ? calculator.send(:ics_farmer_report_rows, targets, records, selected_ics: selected) : []
        { selected_month: month, selected_ics: selected,
          ics_options: calculator.send(:ics_farmer_report_options, records, targets),
          summary: calculator.send(:ics_farmer_report_summary, rows), rows: rows, count: rows.size,
          list_endpoint: "/api/v1/user-dashboard/lists/ics_farmers" }
      end

      def office_section_list_catalog
        catalog = { "summary_ics" => "Total ICS Count", "summary_villages" => "Total Villages Count",
          "summary_farmers" => "Total Farmer Count", "other_activities" => "Main Major Work Indicator - Other" }
        %w[sausar turekela].each do |fco|
          %w[required active vacant].each { |kind| catalog["fco_requirement_#{fco}_#{kind}"] = "#{fco.titleize} #{kind.titleize}" }
          %w[male female].each { |kind| catalog["gender_#{fco}_#{kind}"] = "#{fco.titleize} #{kind.titleize}" }
        end
        catalog
      end

      def office_section_list_payload(type, calculator, vrps, targets)
        records = if type.start_with?("summary_")
          scope = calculator.send(:dashboard_total_afl_farmer_scope)
          columns = %i[fco_id fco fpo_id fpo_name ics_id ics_name]
          if type == "summary_farmers"
            scope.where("NULLIF(BTRIM(tracenet_no), '') IS NOT NULL")
              .order(:fco_id, :ics_id, :id)
              .pluck(:id, :farmer_name, :father_name, :mobile_no, :tracenet_no, *columns, :village_id, :village_name)
              .map { |row| (%i[id farmer_name father_name mobile_no tracenet_no] + columns + %i[village_id village_name]).zip(row).to_h }
          else
            columns += %i[village_id village_name] if type == "summary_villages"
            scope.where.not((type == "summary_villages" ? :village_id : :ics_id) => [nil, ""])
              .group(*columns).order(*columns)
              .pluck(*columns, Arel.sql("COUNT(tracenet_no)"))
              .map { |row| (columns + [:farmer_count]).zip(row).to_h }
          end
        elsif type == "other_activities"
          OfficeDashboardSections.new(calculator: calculator, targets: targets,
            participation: {}, month: nil, fcoc: nil).other_rows
        else
          parts = type.split("_")
          fco, kind = parts.last(2)
          visible = vrps.any? { |vrp| calculator.send(:training_fcoc_text_matches?, vrp.fcoc, fco) }
          if !visible
            []
          elsif %w[required vacant].include?(kind)
            calculator.send(:dashboard_jj_requirement_items, fco.titleize, vrps, targets)
              .select { |item| item[:title].downcase.end_with?(kind) }.map { |item| item.slice(:title, :value) }
          else
            rows = calculator.send(:dashboard_fco_active_vrp_records, fco, nil, vrps)
            rows = rows.select { |vrp| vrp.gender.to_s == kind } if %w[male female].include?(kind)
            rows.map { |vrp| admin_vrp_list_row(vrp, targets.map { |target| target.vrp_id.to_s }, []) }
          end
        end
        { title: office_section_list_catalog.fetch(type), records: records }
      end

      def report_widget_response(widget, config, dashboard_type)
        calculator = dashboard_calculator
        vrps, targets, = filtered_scope(calculator)
        set_filtered_scope(calculator, vrps, targets, [])
        rows = if widget == "cc_jj_work_status"
          CcJjWorkStatusReport.new(calculator: calculator).summary
        else
          DemonstrationMethodReport.new(targets: targets,
            month: params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")).summary
        end
        extra = widget == "cc_jj_work_status" ? { groups: MobileDashboardReportCards.cc_jj_groups(rows) } :
          { cards: OfficeDashboardSections.new(calculator: calculator, targets: targets,
            participation: {}, month: nil, fcoc: nil).demonstration_cards }
        value = widget == "cc_jj_work_status" ? MobileDashboardReportCards.cc_jj_rows(rows) : rows
        { success: true, dashboard_type: dashboard_type, widget: widget, heading: config[:heading],
          value: value, filters: applied_filters, **extra, generated_at: Time.current.iso8601 }
      end

      def cached_user_dashboard_response
        key = user_dashboard_cache_key
        cached = Rails.cache.read(key)
        @dashboard_cache_hit = cached.present?
        return cached if cached

        response = build_user_dashboard_response
        Rails.cache.write(key, response, expires_in: 1.minute) if response[:success]
        response
      rescue StandardError => error
        Rails.logger.warn("User dashboard cache skipped: #{error.class}: #{error.message}")
        build_user_dashboard_response
      end

      PRIMARY_LIST_ALIASES = {
        "total_ics_count" => "summary_ics", "total_villages_count" => "summary_villages",
        "total_farmer_count" => "summary_farmers", "mapped_farmer" => "training_unique_farmers",
        "no_training" => "training_red", "only_1_training" => "training_yellow",
        "one_plus_trainings" => "training_green",
        **OfficeDashboardSections::DEMO.to_h { |key| [key, "demonstration_method"] }
      }.freeze

      def user_dashboard_list_catalog
        admin_dashboard_list_catalog.merge(office_section_list_catalog).merge(
          PRIMARY_LIST_ALIASES.to_h { |key, _type| [key, key.humanize] }
        ).merge(
          "farmer_wise_target_mapping" => "Farmer-wise Target Mapping List",
          "activity_wise_target_mapping" => "Activity-wise Target Mapping List",
          "activity_wise_achievement" => "Activity-wise Achievement List",
          "activity_wise_pending_achievement" => "Activity-wise Pending Achievement List"
        )
      end

      def user_dashboard_widget_catalog
        extras = office_section_list_catalog.except("other_activities").to_h { |key, title| [key, { heading: title, section_card: key }] }
        (OfficeDashboardSections::DEMO + %w[mapped_farmer training_red training_yellow training_green] +
          OfficeDashboardSections::OTHER.keys.map { |key| "other_#{key}" }).each do |key|
          extras[key] = { heading: key.humanize, section_card: key }
        end
        { "total_ics_count" => "summary_ics", "total_villages_count" => "summary_villages",
          "total_farmer_count" => "summary_farmers",
          "total_mapped_main_activities" => "total_mapped_main_activities",
          "total_mapped_sub_activities" => "total_mapped_sub_activities", "no_training" => "training_red",
          "only_1_training" => "training_yellow", "one_plus_trainings" => "training_green" }.each do |key, card|
          extras[key] = { heading: key.humanize, section_card: card }
        end
        extras.merge({
          "cc_jj_work_status" => { heading: "CC and JJ Work Status", path: %i[cc_jj_work_status] },
          "demonstration_method" => { heading: "Demonstration Method", path: %i[demonstration_method] },
          "total_registered" => { heading: "Total Registered Jeevika Jankar", path: %i[cards total_registered_vrp] },
          "final_approved" => { heading: "Final Approved Jeevika Jankar", path: %i[cards final_approved_vrp] },
          "pending_approval" => { heading: "Pending Approval", path: %i[cards vrp_pending_approval] },
          "target_records" => { heading: "Target Records", path: %i[cards vrp_targets_assigned] },
          "activities_assigned" => { heading: "Activities Assigned", path: %i[cards activities_assigned] },
          "bill_approved" => { heading: "Bill Approved", path: %i[cards bill_approved] },
          "bill_pending" => { heading: "Bill Pending", path: %i[cards bill_pending] },
          "total_mapped_villages" => { heading: "Total Mapped Villages", path: %i[dashboard_summary values total_mapped_villages] },
          "targeted_farmers" => { heading: "Targeted Farmers", path: %i[dashboard_summary values targeted_farmers] },
          "farmer_wise_achievement" => { heading: "Farmer-wise Achievement", path: %i[dashboard_summary values farmer_wise_achievement] },
          "farmer_wise_pending_achievement" => { heading: "Farmer-wise Pending Achievement", path: %i[dashboard_summary values farmer_wise_pending_achievement] }
        })
      end

      def office_activity_list_rows(targets, attribute, label)
        targets.group_by { |target| target.public_send(attribute).to_s.squish.downcase }
          .reject { |name, _| name.blank? }.values.map do |group|
            {
              name: group.first.public_send(attribute), activity_type: label, assignment_status: "Mapped",
              main_activity: group.first.main_activity_name, sub_activity: group.first.activity_name,
              sub_activity_count: group.map { |target| target.activity_name.to_s.squish.downcase }.reject(&:blank?).uniq.size,
              target_count: group.size, target_records: group.size,
              target_quantity: number(group.sum { |target| target.target_quantity.to_f }),
              jeevika_jankar_count: group.filter_map(&:vrp_id).uniq.size,
              farmer_count: group.flat_map { |target| mapped_farmer_ids(target) }.uniq.size,
              months: group.filter_map(&:month_name).uniq,
              fco_ids: group.filter_map { |target| target.fco_id.presence }.uniq,
              ics_ids: group.filter_map { |target| target.ics_id.presence }.uniq,
              village_ids: group.filter_map { |target| target.village_id.presence }.uniq
            }
          end.sort_by { |row| [row[:main_activity].to_s.downcase, row[:sub_activity].to_s.downcase] }
          .each_with_index.map { |row, index| row.merge(id: index + 1) }
      end

      def participation_list_fcoc(calculator, options)
        return filter_param(:participation_fcoc) if params.key?(:participation_fcoc)
        return filter_param(:fcoc, :fco) if params.key?(:fcoc) || params.key?(:fco)

        calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
      end

      def user_dashboard_list_payload(list_type)
        return unless user_dashboard_list_catalog.key?(list_type)

        list_type = PRIMARY_LIST_ALIASES.fetch(list_type, list_type)
        calculator = dashboard_calculator
        vrps, targets, options = filtered_scope(calculator)
        summary_vrps, summary_targets = summary_scope(calculator)
        if office_section_list_catalog.key?(list_type)
          list_vrps, list_targets = list_type.start_with?("summary_") ? [summary_vrps, summary_targets] : [vrps, targets]
          set_filtered_scope(calculator, list_vrps, list_targets, [], summary_vrps: summary_vrps, summary_targets: summary_targets)
          return office_section_list_payload(list_type, calculator, list_vrps, list_targets)
        end
        if %w[total_mapped_main_activities total_mapped_sub_activities].include?(list_type)
          set_filtered_scope(calculator, summary_vrps, summary_targets, [], summary_vrps: summary_vrps, summary_targets: summary_targets)
          attribute, label = list_type == "total_mapped_main_activities" ? [:main_activity_name, "Main Activity"] : [:activity_name, "Sub Activity"]
          return { title: user_dashboard_list_catalog.fetch(list_type), records: office_activity_list_rows(summary_targets, attribute, label) }
        end

        set_filtered_scope(calculator, vrps, targets, [], summary_vrps: summary_vrps, summary_targets: summary_targets)
        if list_type == "cc_jj_work_status"
          return { title: user_dashboard_list_catalog.fetch(list_type), headers: CcJjWorkStatusReport::HEADERS,
            records: CcJjWorkStatusReport.new(calculator: calculator).rows }
        end
        if list_type == "demonstration_method"
          return { title: user_dashboard_list_catalog.fetch(list_type), headers: DemonstrationMethodReport::HEADERS,
            records: DemonstrationMethodReport.new(targets: targets, month: params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")).rows }
        end
        if %w[training_unique_farmers training_red training_pending training_yellow training_green].include?(list_type)
          months = calculator.send(:dashboard_month_options_for_targets, targets)
          participation_month = selected_month(:participation_month, months, calculator, targets)
          participation_fcoc = participation_list_fcoc(calculator, options)
          status = {
            "training_unique_farmers" => "unique", "training_red" => "red", "training_pending" => "pending",
            "training_yellow" => "yellow", "training_green" => "green"
          }.fetch(list_type)
          rows = calculator.send(:training_participation_web_rows,
            status: status, month_name: participation_month, fcoc_name: participation_fcoc)
          return { title: user_dashboard_list_catalog.fetch(list_type), records: rows }
        end
        bills = filtered_bills(calculator, vrps)
        set_filtered_scope(calculator, vrps, targets, bills)
        unless list_type.start_with?("training_", "farmer_wise_", "weekly_", "activity_wise_") || %w[targeted_farmers ics_farmers].include?(list_type)
          @admin_dashboard_api_context = { web: calculator, vrps: vrps, targets: targets, all_targets: targets, bills: bills }
          return admin_dashboard_list_payload(list_type)
        end
        months = calculator.send(:dashboard_month_options_for_targets, targets)
        participation_month = selected_month(:participation_month, months, calculator, targets)
        participation_fcoc = participation_list_fcoc(calculator, options)
        participation_records = calculator.send(:dashboard_training_participation_records, month_name: participation_month, fcoc_name: participation_fcoc)
        population = calculator.send(:training_participation_population_rows,
          month_name: participation_month, fcoc_name: participation_fcoc, records: participation_records)
        weekly_month = selected_month(:weekly_target_month, months, calculator)
        weekly_fcoc = filter_param(:weekly_target_fcoc) || calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
        weekly_targets = calculator.send(:dashboard_targets_for_month, targets, weekly_month)
        weekly_targets = weekly_targets.select { |target| calculator.send(:training_target_matches_fcoc?, target, weekly_fcoc) } if weekly_fcoc.present?
        weekly_rows = calculator.send(:weekly_activity_target_farmer_status_rows,
          weekly_targets, month_name: weekly_month, fcoc_name: weekly_fcoc, week_number: selected_week)
        ics_month = params.key?(:ics_report_month) ? filter_param(:ics_report_month) : participation_month
        ics_targets = calculator.send(:training_participation_targets_for_dashboard,
          month_name: ics_month, fcoc_name: participation_fcoc)
        ics_records = calculator.send(:dashboard_training_participation_records,
          month_name: ics_month, fcoc_name: participation_fcoc)
        selected_ics = filter_param(:ics_report_ics)
        ics_rows = selected_ics.present? ? calculator.send(:ics_farmer_report_rows, ics_targets, ics_records, selected_ics: selected_ics) : []

        context = {
          web: calculator, vrps: vrps, targets: targets, all_targets: targets, bills: bills,
          participation_records: participation_records, participation_population: population,
          participation_month: participation_month, participation_month_value: participation_month,
          weekly_rows: weekly_rows, ics_rows: ics_rows
        }
        @admin_dashboard_api_context = context
        payload = admin_dashboard_list_payload(list_type)
        return unless payload

        payload.merge(title: user_dashboard_list_catalog.fetch(list_type))
      rescue StandardError => error
        Rails.logger.error("User dashboard list API failed: #{error.class}: #{error.message}")
        nil
      end

      def build_user_dashboard_response
        @calculation_stage = "authentication"

        @calculation_stage = "dashboard_context"
        calculator = dashboard_calculator
        @calculation_stage = "visible_vrps_and_targets"
        vrps, targets, options = filtered_scope(calculator)
        summary_vrps, summary_targets = summary_scope(calculator)
        @calculation_stage = "visible_bills"
        bills = filtered_bills(calculator, vrps)
        set_filtered_scope(calculator, vrps, targets, bills, summary_vrps: summary_vrps, summary_targets: summary_targets)

        @calculation_stage = "participation_month_options"
        months = calculator.send(:dashboard_month_options_for_targets, targets)
        participation_month = selected_month(:participation_month, months, calculator, targets)
        participation_fcoc = filter_param(:participation_fcoc) || calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
        @calculation_stage = "participation_records"
        records = calculator.send(:dashboard_training_participation_records, month_name: participation_month, fcoc_name: participation_fcoc)
        @calculation_stage = "participation_counts"
        participation = calculator.send(:training_participation_dashboard_counts,
          month_name: participation_month, fcoc_name: participation_fcoc, records: records)
        @calculation_stage = "weekly_targets"
        weekly_month = selected_month(:weekly_target_month, months, calculator)
        weekly_targets = calculator.send(:dashboard_targets_for_month, targets, weekly_month)
        weekly_fcoc = filter_param(:weekly_target_fcoc) || calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
        if weekly_fcoc.present?
          weekly_targets = weekly_targets.select { |target| calculator.send(:training_target_matches_fcoc?, target, weekly_fcoc) }
        end
        weekly_rows = calculator.send(:weekly_activity_target_farmer_status_rows,
          weekly_targets,
          month_name: weekly_month,
          fcoc_name: weekly_fcoc,
          week_number: selected_week)
        weekly_counts = calculator.send(:weekly_activity_target_status_counts_for_rows, weekly_rows)
        weekly = calculator.send(:dashboard_weekly_activity_summary_totals,
          weekly_targets,
          participation,
          week_number: selected_week).merge(status_counts: weekly_counts, rows_count: weekly_rows.size)

        @calculation_stage = "response_payload"
        section_builder = OfficeDashboardSections.new(calculator: calculator, targets: targets,
          participation: participation, month: participation_month, fcoc: participation_fcoc)
        sections = section_builder.sections
        {
          success: true,
          message: "User dashboard fetched successfully.",
          dashboard_type: "user",
          sections: sections,
          user: user_payload,
          filters: applied_filters,
          filter_options: options,
          cc_jj_work_status: section_builder.send(:call_report).summary,
          demonstration_method: calculator.instance_variable_get(:@demonstration_method_report).summary,
          cards: card_payload(calculator, vrps, targets, bills),
          dashboard_summary: dashboard_summary_payload(calculator, targets, participation, weekly),
          farmer_training_participation_status: participation_payload(participation, participation_month, participation_fcoc, months),
          weekly_activity_target_status: weekly_payload(weekly, weekly_month, weekly_fcoc),
          ics_wise_farmer_report: office_ics_report(calculator, targets, records, participation_month, participation_fcoc),
          monthly_target_summary: monthly_summary(targets),
          hierarchy: hierarchy_payload(calculator),
          generated_at: Time.current.iso8601
        }
      rescue StandardError => error
        Rails.logger.error("User dashboard API failed at #{@calculation_stage}: #{error.class}: #{error.message}\n#{error.backtrace&.first(15)&.join("\n")}")
        {
          success: false,
          message: "User dashboard could not be loaded.",
          error: "dashboard_calculation_failed",
          failed_stage: @calculation_stage,
          exception: error.class.name,
          missing_method: (error.name.to_s if error.respond_to?(:name)),
          request_id: request.request_id
        }
      end

      def render_vrp_error
        render json: { success: false, message: "This API is for User login, not Jeevika Jankar login." }, status: :forbidden
      end

      def user_dashboard_cache_key
        version_parts = [
          cache_table_version(TargetMapping),
          cache_table_version(VrpIcsMapping),
          cache_table_version(Vrp),
          cache_table_version(User),
          cache_table_version(Afl),
          cache_module_records_version(%w[
            training-form
            jeevika-jankar-bill-process
            approval-master
            vrp-approval-history
            user-hierarchy-mapping
            new-user
          ])
        ]
        filters = admin_dashboard_cache_filters
        user_key = current_api_user_payload.sort.to_h
        ["api-v1-user-dashboard-office-v11", Date.current.to_s, user_key, filters, version_parts].to_json
      end

      def cache_table_version(model)
        begin
          version = model.pick(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(MAX(id), 0)"), Arel.sql("COALESCE(EXTRACT(EPOCH FROM MAX(updated_at)), 0)"))
          "#{model.table_name}:#{version.join(":")}"
        end
      rescue StandardError
        "#{model.name}:unknown"
      end

      def cache_module_records_version(module_slugs)
        slugs = Array(module_slugs).map(&:to_s).sort
        begin
          scope = ModuleRecord.where(module_slug: slugs)
          version = scope.pick(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(MAX(id), 0)"), Arel.sql("COALESCE(EXTRACT(EPOCH FROM MAX(updated_at)), 0)"))
          "module_records:#{version.join(":")}"
        end
      rescue StandardError
        "module_records:unknown"
      end

      def dashboard_calculator
        OfficeDashboardCalculator.new.tap do |controller|
          controller.request = request
          controller.params = params
          controller.instance_variable_set(:@current_app_user, current_api_user_payload)
        end
      end

      def filtered_scope(calculator)
        @calculation_stage = "dashboard_vrps"
        vrps = calculator.send(:dashboard_vrps).to_a
        @calculation_stage = "dashboard_target_mappings"
        targets = calculator.send(:dashboard_target_mappings).to_a
        preload_dashboard_associations!(targets)
        @calculation_stage = "dashboard_search_filter"
        vrps, targets = search_scope(vrps, targets)
        @calculation_stage = "dashboard_activity_filters"
        months = values(targets, :month_name)
        selected_dashboard_month = params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")
        if selected_dashboard_month.present?
          targets = targets.select { |target| same?(target.month_name, selected_dashboard_month) }
          vrps = restrict_vrps_to_targets(vrps, targets)
        end
        options = { months: months, main_activities: values(targets, :main_activity_name) }
        selected_main_activity = params.key?(:main_activity) ? filter_param(:main_activity) : default_farmer_activity_filter(calculator, values(targets.select { |target|
          month = params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")
          month.blank? || same?(target.month_name, month)
        }, :main_activity_name))
        @resolved_main_activity = selected_main_activity
        selected_sub_activity = filter_param(:sub_activity)
        legacy_activity = filter_param(:activity)
        if selected_main_activity.present?
          normalized_main = calculator.send(:normalize_dashboard_text, selected_main_activity)
          main_matches = targets.select { |target| calculator.send(:normalize_dashboard_text, target.main_activity_name) == normalized_main }
          targets = main_matches
        elsif legacy_activity.present?
          targets = targets.select { |target| same?(target.main_activity_name, legacy_activity) || same?(target.activity_name, legacy_activity) }
        end
        options[:sub_activities] = values(targets, :activity_name)
        targets = targets.select { |target| same?(target.activity_name, selected_sub_activity) } if selected_sub_activity.present?
        options[:activities] = (options[:main_activities] + options[:sub_activities]).uniq.sort
        if selected_main_activity.present? || selected_sub_activity.present? || legacy_activity.present?
          vrps = restrict_vrps_to_targets(vrps, targets)
        end
        options[:fcos] = values(vrps, :fcoc)
        @calculation_stage = "dashboard_fcoc_filter"
        vrps, targets = filter_vrps(vrps, targets, :fcoc, filter_param(:fcoc, :fco))
        options[:cluster_incharges] = values(vrps, :cluster_incharge)
        @calculation_stage = "dashboard_cluster_filter"
        vrps, targets = filter_vrps(vrps, targets, :cluster_incharge, filter_param(:cluster_incharge))
        @calculation_stage = "dashboard_ics_filter"
        options[:ics_names] = targets.filter_map { |target| (target.ics_name.presence || target.ics_id).to_s.strip.presence }.uniq.sort
        selected_ics = filter_param(:ics, :ics_name)
        if selected_ics.present?
          targets = targets.select { |target| same?(target.ics_name.presence || target.ics_id, selected_ics) }
          vrps = restrict_vrps_to_targets(vrps, targets)
        end
        options[:months] = months
        @calculation_stage = "dashboard_month_filter"
        selected_dashboard_month = params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")
        if selected_dashboard_month.present?
          targets = targets.select { |t| same?(t.month_name, selected_dashboard_month) }
          vrps = restrict_vrps_to_targets(vrps, targets)
        end
        options[:post_wise_names] = values(vrps, :role)
        @calculation_stage = "dashboard_post_filter"
        vrps, targets = filter_vrps(vrps, targets, :role, filter_param(:post, :post_wise_name))
        options[:vrps] = vrps.map { |v| { id: v.id, name: v.name, user_name: v.user_name } }
        @calculation_stage = "dashboard_vrp_filter"
        selected_vrp_id = filter_param(:vrp_id)
        if selected_vrp_id.present?
          vrps = vrps.select { |v| v.id.to_s == selected_vrp_id.to_s }
          targets = targets.select { |t| t.vrp_id.to_s == selected_vrp_id.to_s }
        end
        [vrps, targets, options]
      end

      def search_scope(vrps, targets)
        query = filter_param(:search)
        return [vrps, targets] if query.blank?

        query = query.to_s.downcase.strip
        vrps = vrps.select { |v| [v.name, v.mobile_no, v.role, v.fcoc, v.cluster_incharge].any? { |x| x.to_s.downcase.include?(query) } }
        targets = targets.select { |t| [t.vrp&.name, t.month_name, t.village_name, t.main_activity_name, t.activity_name].any? { |x| x.to_s.downcase.include?(query) } }
        [vrps, targets]
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
        Rails.logger.debug("User dashboard preload skipped: #{error.class}: #{error.message}")
      end

      def filter_vrps(vrps, targets, attribute, selected)
        return [vrps, targets] if selected.blank?
        calculator = dashboard_calculator if attribute == :fcoc
        filtered = vrps.select do |vrp|
          if calculator
            calculator.send(:training_fcoc_text_matches?, vrp.fcoc, selected)
          else
            same?(vrp.public_send(attribute), selected)
          end
        end
        ids = id_lookup(filtered)
        [filtered, targets.select { |t| ids.key?(t.vrp_id.to_s) }]
      end

      def restrict_vrps_to_targets(vrps, targets)
        ids = targets.each_with_object({}) { |target, lookup| lookup[target.vrp_id.to_s] = true }
        vrps.select { |vrp| ids.key?(vrp.id.to_s) }
      end

      def id_lookup(records)
        records.each_with_object({}) { |record, lookup| lookup[record.id.to_s] = true }
      end

      def filtered_bills(calculator, vrps)
        ids = id_lookup(vrps)
        scope = ModuleRecord.where(module_slug: "jeevika-jankar-bill-process")
        return [] if ids.blank?

        scope = scope.where("COALESCE(NULLIF(data::jsonb ->> 'select_vrp', ''), NULLIF(data::jsonb ->> 'vrp_id', ''), data::jsonb ->> 'jeevika_jankar_id') IN (?)", ids.keys)
        selected_bill_month = params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")
        if selected_bill_month.present?
          scope = scope.where("LOWER(BTRIM(data::jsonb ->> 'bill_month')) = ?", selected_bill_month.to_s.strip.downcase)
        end
        records = scope.to_a
          .select { |record| calculator.send(:jeevika_jankar_bill_blocks_duplicate?, record) && calculator.send(:jeevika_jankar_bill_record_visible?, record) }
        if calculator.send(:module_cluster_incharge_login?)
          records.select! do |record|
            bill_vrp = calculator.send(:jeevika_bill_vrp, record)
            bill_vrp.present? && ids.key?(bill_vrp.id.to_s)
          end
        end
        records = records
          .select { |record| ids.key?((record.data["select_vrp"].presence || record.data["vrp_id"].presence || record.data["jeevika_jankar_id"]).to_s) }
        selected_activity = filter_param(:activity)
        selected_main_activity = filter_param(:main_activity)
        selected_sub_activity = filter_param(:sub_activity)
        if selected_activity.present? || selected_main_activity.present? || selected_sub_activity.present?
          records.select! do |record|
            calculator.send(:jeevika_bill_detail_rows, record).any? do |item|
              legacy_match = selected_activity.blank? || same?(item["main_activity"], selected_activity) || same?(item["activity"], selected_activity)
              main_match = selected_main_activity.blank? || same?(item["main_activity"], selected_main_activity)
              sub_match = selected_sub_activity.blank? || same?(item["activity"], selected_sub_activity)
              legacy_match && main_match && sub_match
            end
          end
        end
        records
      end

      # Summary follows the same role/FCO/ICS scope as the web dashboard.
      # Participation and Demonstration continue to use month/activity filters.
      def summary_scope(calculator)
        vrps = calculator.send(:dashboard_vrps).to_a
        targets = calculator.send(:dashboard_target_mappings).to_a
        preload_dashboard_associations!(targets)
        vrps, targets = search_scope(vrps, targets)
        vrps, targets = filter_vrps(vrps, targets, :fcoc, filter_param(:fcoc, :fco))
        vrps, targets = filter_vrps(vrps, targets, :cluster_incharge, filter_param(:cluster_incharge))

        selected_ics = filter_param(:ics, :ics_name)
        if selected_ics.present?
          targets = targets.select { |target| same?(target.ics_name.presence || target.ics_id, selected_ics) }
          vrps = restrict_vrps_to_targets(vrps, targets)
        end

        vrps, targets = filter_vrps(vrps, targets, :role, filter_param(:post, :post_wise_name))
        selected_vrp_id = filter_param(:vrp_id)
        if selected_vrp_id.present?
          vrps = vrps.select { |vrp| vrp.id.to_s == selected_vrp_id.to_s }
          targets = targets.select { |target| target.vrp_id.to_s == selected_vrp_id.to_s }
        end
        [vrps, targets]
      end

      def set_filtered_scope(calculator, vrps, targets, bills, summary_vrps: nil, summary_targets: nil)
        calculator.apply_dashboard_scope(
          vrps: vrps, targets: targets, bills: bills,
          summary_vrps: summary_vrps, summary_targets: summary_targets
        )
      end

      def selected_month(key, months, calculator, targets = nil)
        return filter_param(key) if params.key?(key)
        return filter_param(:month) if params.key?(:month)

        Date.current.prev_month.strftime("%B")
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

      def dashboard_summary_payload(calculator, targets, participation, weekly)
        items = dashboard_summary_values(calculator, targets, participation, weekly)
        summary_cards = calculator.send(:dashboard_summary_cards, targets).map do |card|
          key = OfficeDashboardSections::SUMMARY.fetch(card[:title])
          { key: key, title: card[:title], value: card[:value],
            list_endpoint: "/api/v1/user-dashboard/lists/#{key}",
            export_endpoint: "/api/v1/user-dashboard/lists/#{key}/export" }
        end
        {
          cards: summary_cards,
          counts: summary_cards.to_h { |card| [card[:key], card[:value]] },
          language: dashboard_language,
          items: items.map do |key, value|
            labels = DASHBOARD_SUMMARY_LABELS.fetch(key)
            {
              key: key,
              label: labels.fetch(dashboard_language),
              label_en: labels.fetch(:en),
              label_hi: labels.fetch(:hi),
              value: value
            }
          end,
          values: items
        }
      end

      def dashboard_summary_values(calculator, targets, participation, weekly)
        # Keep duplicate summary fields consistent with the five web Summary cards.
        # Only Participation-derived values below use the selected month/activity scope.
        summary_targets = calculator.instance_variable_get(:@office_summary_targets).presence || targets
        main_activity_count = summary_targets.filter_map { |target| target.main_activity_name.to_s.strip.presence }.uniq.size
        sub_activity_count = summary_targets.filter_map { |target| target.activity_name.to_s.strip.presence }.uniq.size
        village_count = summary_targets.map { |target| [target.village_id.to_s.strip, target.village_name.to_s.strip.downcase] }
          .reject { |id, name| id.blank? && name.blank? }
          .uniq
          .size
        targeted_farmer_count = participation[:total].to_i
        farmer_target_mapping = participation[:target_map_total].to_i
        farmer_achievement = participation[:completed_target_map_total].to_i
        farmer_pending = [farmer_target_mapping - farmer_achievement, 0].max
        activity_target_mapping = weekly[:target]
        activity_achievement = weekly[:completed]
        activity_pending = weekly[:pending]

        {
          total_mapped_villages: village_count,
          targeted_farmers: targeted_farmer_count,
          total_mapped_main_activities: main_activity_count,
          total_mapped_sub_activities: sub_activity_count,
          farmer_wise_target_mapping: farmer_target_mapping,
          farmer_wise_achievement: farmer_achievement,
          farmer_wise_pending_achievement: farmer_pending,
          activity_wise_target_mapping: number(activity_target_mapping),
          activity_wise_achievement: number(activity_achievement),
          activity_wise_pending_achievement: number(activity_pending)
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
        status_counts = totals[:status_counts] || {}
        {
          selected_month: month,
          selected_fcoc: fcoc,
          selected_week: selected_week,
          target_mila: number(totals[:target]),
          completed: number(totals[:completed]),
          partial: status_counts[:yellow].to_i,
          pending: number(totals[:pending]),
          target_assigned: status_counts[:total].to_i,
          rows_count: totals[:rows_count].to_i
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
        explicit = %i[search activity main_activity sub_activity fcoc fco cluster_incharge ics ics_name month post post_wise_name vrp_id participation_month participation_fcoc weekly_target_month weekly_target_fcoc weekly_target_week ics_report_month ics_report_ics]
          .filter_map { |key| value = filter_param(key); [key, value] if value.present? }
          .to_h
        explicit[:month] = Date.current.prev_month.strftime("%B") unless params.key?(:month)
        explicit[:main_activity] = @resolved_main_activity if @resolved_main_activity.present? && !params.key?(:main_activity)
        explicit
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

      def default_farmer_activity_filter(calculator, activity_options)
        Array(activity_options).find do |activity|
          %w[Farmer\ Activity Farmers'\ Training Farmers\ Training].any? do |label|
            calculator.send(:normalize_dashboard_text, activity) == calculator.send(:normalize_dashboard_text, label)
          end
        end
      end

      def number(value)
        value.to_f == value.to_i ? value.to_i : value.to_f.round(2)
      end

      def dashboard_language
        value = params[:language].presence || params[:lang].presence || params[:locale].presence
        value.to_s.downcase.start_with?("hi") ? :hi : :en
      end

      DASHBOARD_SUMMARY_LABELS = {
        total_mapped_villages: {
          en: "Total Mapped Villages",
          hi: "कुल मैप किए गए गाँव"
        },
        targeted_farmers: {
          en: "Targeted Farmers",
          hi: "लक्षित किसानों की संख्या"
        },
        total_mapped_main_activities: {
          en: "Total Mapped Main Activities",
          hi: "कुल मैप की गई मुख्य गतिविधियाँ"
        },
        total_mapped_sub_activities: {
          en: "Total Mapped Sub-Activities",
          hi: "कुल मैप की गई उप-गतिविधियाँ"
        },
        farmer_wise_target_mapping: {
          en: "Farmer-wise Target Mapping",
          hi: "किसान-वार लक्ष्य मैपिंग"
        },
        farmer_wise_achievement: {
          en: "Farmer-wise Achievement",
          hi: "किसान-वार उपलब्धि"
        },
        farmer_wise_pending_achievement: {
          en: "Farmer-wise Pending Achievement",
          hi: "किसान-वार लंबित उपलब्धि"
        },
        activity_wise_target_mapping: {
          en: "Activity-wise Target Mapping",
          hi: "गतिविधि-वार लक्ष्य मैपिंग"
        },
        activity_wise_achievement: {
          en: "Activity-wise Achievement",
          hi: "गतिविधि-वार उपलब्धि"
        },
        activity_wise_pending_achievement: {
          en: "Activity-wise Pending Achievement",
          hi: "गतिविधि-वार लंबित उपलब्धि"
        }
      }.freeze
    end
  end
end
