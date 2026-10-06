module Api
  module V1
    class TargetMappingsController < BaseController
      DEFAULT_PER_PAGE = 100
      MAX_PER_PAGE = 200
      SUMMARY_MODES = %w[main_activity sub_activity raw].freeze
      SUMMARY_MODE_ALIASES = {
        "main_major_work_indicator" => "main_activity",
        "main_major_work_indicators" => "main_activity",
        "sub_major_work_indicator" => "sub_activity",
        "sub_major_work_indicators" => "sub_activity"
      }.freeze

      # This endpoint deliberately delegates filtering and visibility to the web
      # Target Mapping controller.  The mobile list and the web list therefore use
      # the same permitted VRPs, FCO/ICS filters and activity grouping.
      def recent
        mode = requested_summary_mode
        mappings = web_filtered_mappings
        records = mode == "raw" ? raw_records(mappings) : summary_records(mappings, mode)
        page, per_page = pagination_values
        paged_records = records.slice((page - 1) * per_page, per_page) || []

        render json: {
          success: true,
          message: "Recent target mappings fetched successfully.",
          summary_mode: mode,
          target_mappings: paged_records,
          records: paged_records,
          count: records.size,
          pagination: {
            page: page,
            per_page: per_page,
            total_count: records.size,
            total_pages: (records.size.to_f / per_page).ceil
          }
        }, status: :ok
      end

      # Target Mapping > Jeevika Jankar Mapped Farmers.  One row is returned
      # for each farmer assigned to a target mapping, with both the complete
      # target context and the farmer master data the web page uses.
      # `web_filtered_mappings` applies the exact web visibility policy: an
      # admin receives all mappings, while a JJ receives only their own.
      def mapped_farmers
        rows = filtered_mapped_farmer_rows
        page, per_page = pagination_values
        paged_rows = rows.slice((page - 1) * per_page, per_page) || []

        render json: {
          success: true,
          message: "Jeevika Jankar mapped farmers fetched successfully.",
          records: paged_rows,
          mapped_farmers: paged_rows,
          count: rows.size,
          filters: mapped_farmer_filter_payload,
          export_endpoint: "#{request.base_url}/api/v1/target-mappings/mapped-farmers/export",
          pagination: pagination_payload(rows.size, page, per_page)
        }, status: :ok
      end

      def mapped_farmers_export
        rows = filtered_mapped_farmer_rows
        headers = mapped_farmer_export_headers
        file = XlsxExporter.generate(
          headers: headers,
          rows: rows.map { |row| headers.map { |header| export_value(row[header]) } },
          sheet_name: "JJ Mapped Farmers"
        )
        send_data file,
          filename: "jeevika-jankar-mapped-farmers-#{Date.current}.xlsx",
          type: XlsxExporter::MIME_TYPE,
          disposition: "attachment"
      end

      private

      def web_filtered_mappings(apply_search: true)
        controller = web_target_mappings_controller
        scope = controller.send(:filtered_visible_target_mappings)
        scope = merge_hierarchy_target_mappings(scope, controller)
        scope = apply_search(scope) if apply_search && params[:search].present?
        scope.includes(:vrp, :vrp_ics_mapping).order("target_mappings.updated_at DESC").to_a
      end

      def filtered_mapped_farmer_rows
        mappings = web_filtered_mappings(apply_search: false)
        farmer_ids = mappings.flat_map { |mapping| Array(mapping.afl_ids) }.map(&:to_s).compact_blank.uniq
        farmers_by_id = Afl.where(id: farmer_ids).index_by { |farmer| farmer.id.to_s }
        rows = mappings.flat_map do |mapping|
          Array(mapping.afl_ids).map(&:to_s).compact_blank.uniq.map do |farmer_id|
            mapped_farmer_payload(mapping, farmers_by_id[farmer_id], farmer_id)
          end
        end
        search_mapped_farmer_rows(rows)
      end

      def mapped_farmer_payload(mapping, farmer, farmer_id)
        weekly_targets = mapping.weekly_target_values
        farmer_data = farmer ? farmer.attributes.except("qrcode") : {}
        {
          id: "#{mapping.id}-#{farmer_id}",
          target_mapping_id: mapping.id.to_s,
          jeevika_jankar_id: mapping.vrp_id.to_s,
          jeevika_jankar_name: mapping.vrp&.name.presence || mapping.vrp&.user_name,
          jeevika_jankar_mobile_no: mapping.vrp&.mobile_no,
          cc_name: mapping.vrp&.cluster_incharge,
          fco_id: mapping.fco_id,
          fco_name: mapping.fco_name.presence || mapping.vrp&.fcoc,
          ics_id: mapping.ics_id,
          ics_name: mapping.ics_name,
          village_id: mapping.village_id,
          village_name: mapping.village_name,
          month: mapping.month_name,
          completion_date: mapping.completion_date&.iso8601,
          main_activity: mapping.main_activity_name,
          sub_activity: mapping.activity_name,
          main_activity_type: target_main_activity_type(mapping),
          farmer_target: mapping.target_quantity,
          cc_target: mapping.cc_target,
          opg_training_target: mapping.opg_training_target,
          general_training_meeting_target: mapping.week_wise_opg_target,
          input_demo_inm_target: mapping.input_demo_inm_target,
          input_demo_pm_target: mapping.input_demo_pm_target,
          ffs_target: mapping.ffs_target,
          week_1_target: weekly_targets[0], week_2_target: weekly_targets[1],
          week_3_target: weekly_targets[2], week_4_target: weekly_targets[3],
          farmer_id: farmer_id,
          farmer_name: farmer&.farmer_name,
          father_name: farmer&.father_name,
          tracenet_no: farmer&.tracenet_no,
          mobile_no: farmer&.mobile_no,
          farmer_fco_id: farmer&.fco_id,
          farmer_fco_name: farmer&.fco,
          farmer_ics_id: farmer&.ics_id,
          farmer_ics_name: farmer&.ics_name,
          farmer_village_id: farmer&.village_id,
          farmer_village_name: farmer&.village_name,
          farmer_details: farmer_data,
          created_at: mapping.created_at&.iso8601,
          updated_at: mapping.updated_at&.iso8601
        }
      end

      def search_mapped_farmer_rows(rows)
        term = params[:search].to_s.strip.downcase
        return rows if term.blank?

        rows.select { |row| row.values.any? { |value| value.to_s.downcase.include?(term) } }
      end

      def mapped_farmer_filter_payload
        %w[month main_activity sub_activity fco fco_id fcoc ics ics_id village village_id vrp_id search]
          .each_with_object({}) { |key, result| result[key] = params[key] if params[key].present? }
      end

      def pagination_payload(total_count, page, per_page)
        { page: page, per_page: per_page, total_count: total_count, total_pages: (total_count.to_f / per_page).ceil }
      end

      def mapped_farmer_export_headers
        %w[
          target_mapping_id jeevika_jankar_id jeevika_jankar_name jeevika_jankar_mobile_no cc_name
          fco_id fco_name ics_id ics_name village_id village_name month completion_date
          main_activity sub_activity main_activity_type farmer_target cc_target
          opg_training_target general_training_meeting_target input_demo_inm_target input_demo_pm_target ffs_target
          week_1_target week_2_target week_3_target week_4_target
          farmer_id farmer_name father_name tracenet_no mobile_no
          farmer_fco_id farmer_fco_name farmer_ics_id farmer_ics_name farmer_village_id farmer_village_name
        ]
      end

      def export_value(value)
        value.is_a?(Array) || value.is_a?(Hash) ? value.to_json : value
      end

      def web_target_mappings_controller
        controller = ::TargetMappingsController.new
        controller.request = request
        controller.params = normalized_web_params
        controller.instance_variable_set(:@current_app_user, current_api_user_payload)
        controller
      end

      # API-only: the web Target Mapping controller/page has no concept of the
      # Agronomist/Manager hierarchy (user-hierarchy-mapping) -- its own scope
      # only returns VRPs this login personally registered or directly
      # manages. An Agricultural Specialist/Manager overseeing a cluster of
      # Cluster Incharges never saw the target mappings those Cluster
      # Incharges' own JJs saved here, even though their dashboard
      # (OfficeDashboardCalculator#dashboard_vrps) already counts them -- so
      # this API under-reported vs. that user's own dashboard (e.g. "713"
      # saved records showing far fewer for a Sausar/specialist login).
      #
      # This widens only the mobile API's result set by re-running the exact
      # same filters (reusing the web controller's own, unmodified
      # `target_mapping_fco_filter_values` method) against the hierarchy
      # VRPs and merging the two ID sets. The web controller/page itself is
      # never modified by this -- it is only invoked read-only via `send`.
      # `dashboard_hierarchy_vrps` returns [] for anyone not named as an
      # overseer in an active hierarchy mapping, so this is a no-op for
      # ordinary CC/FCO-C/VRP logins, and summary modes (dashboard card
      # drill-downs) are left untouched.
      def merge_hierarchy_target_mappings(own_scope, controller)
        return own_scope unless requested_summary_mode == "raw"
        return own_scope if controller.send(:admin_login?) || controller.send(:non_admin_vrp_login?)

        policy = controller.send(:dashboard_target_policy)
        return own_scope if policy.send(:dashboard_global_view_user?)

        own_ids = Array(policy.send(:dashboard_visible_vrp_ids))
        hierarchy_ids = Array(policy.send(:dashboard_hierarchy_vrps)).map(&:id) - own_ids
        return own_scope if hierarchy_ids.blank?

        values = normalized_web_params
        hierarchy_scope = TargetMapping.where(vrp_id: hierarchy_ids)
        hierarchy_scope = hierarchy_scope.where(vrp_id: values[:vrp_id]) if values[:vrp_id].present?
        hierarchy_scope = hierarchy_scope.where("LOWER(BTRIM(month_name)) = ?", values[:month].to_s.strip.downcase) if values[:month].present?
        hierarchy_scope = hierarchy_scope.where("LOWER(BTRIM(main_activity_name)) = ?", values[:main_activity].to_s.strip.downcase) if values[:main_activity].present?
        hierarchy_scope = hierarchy_scope.where("LOWER(BTRIM(activity_name)) = ?", values[:sub_activity].to_s.strip.downcase) if values[:sub_activity].present?
        fco_filter_values = controller.send(:target_mapping_fco_filter_values, values[:fcoc].presence || values[:fco_id].presence)
        hierarchy_scope = hierarchy_scope.where("LOWER(BTRIM(fco_id)) IN (:fcoc) OR LOWER(BTRIM(fco_name)) IN (:fcoc)", fcoc: fco_filter_values) if fco_filter_values.any?
        hierarchy_scope = hierarchy_scope.where("LOWER(BTRIM(ics_id)) = :ics OR LOWER(BTRIM(ics_name)) = :ics", ics: values[:ics].to_s.strip.downcase) if values[:ics].present?

        TargetMapping.where(id: own_scope.pluck(:id) + hierarchy_scope.pluck(:id))
      end

      # The app sends `fco=All` and `ics=All`; the web form omits those values.
      # Normalize both forms before using the web controller's filter methods.
      def normalized_web_params
        values = params.to_unsafe_h.deep_dup
        %w[month main_activity sub_activity ics].each do |key|
          values.delete(key) if all_filter_value?(values[key])
        end

        fco = values["fcoc"].presence || values["fco_id"].presence || values["fco"].presence
        values.delete("fco")
        if all_filter_value?(fco)
          values.delete("fcoc")
          values.delete("fco_id")
        elsif fco.present?
          values["fcoc"] = fco
        end

        # Raw is the Recent Target Mappings web-table mode.  Do not pass a
        # summary_mode to the web controller in that case: its presence invokes
        # the dashboard drill-down scope and silently drops saved mappings.
        # This keeps `month=All` as every visible saved target mapping.
        mode = requested_summary_mode
        if mode == "raw"
          values.delete("summary_mode")
        else
          values["summary_mode"] = mode
        end
        ActionController::Parameters.new(values)
      end

      def all_filter_value?(value)
        normalized = value.to_s.strip.downcase
        normalized.blank? || normalized == "all" || normalized.start_with?("all ")
      end

      def requested_summary_mode
        requested = (params[:summary_mode].presence || params[:list_type]).to_s.strip.downcase
        # The web page headed "Recent Target Mappings" is a row-level table.
        # Make the API match it when no mode is supplied; callers that render
        # dashboard count cards can still explicitly request either summary.
        return "raw" if requested.blank?

        requested = SUMMARY_MODE_ALIASES.fetch(requested, requested)
        SUMMARY_MODES.include?(requested) ? requested : "raw"
      end

      def summary_records(mappings, mode)
        controller = web_target_mappings_controller
        controller.instance_variable_set(:@target_summary_mode, mode)
        controller.send(:target_mapping_summary_rows, mappings).map do |row|
          # Keep the web names and add the mobile table names. Both values are
          # generated from the same grouped target rows.
          row.merge(
            main_major_work_indicator: row[:main_activity],
            sub_major_work_indicator: row[:sub_activity],
            mapped_farmer_count: row[:farmer_count],
            target_mapping_count: row[:target_count]
          )
        end
      end

      def raw_records(mappings)
        farmer_ids = mappings.flat_map { |mapping| Array(mapping.afl_ids) }.map(&:to_s).compact_blank.uniq
        farmers_by_id = Afl.where(id: farmer_ids).index_by { |farmer| farmer.id.to_s }
        mappings.map { |mapping| mapping_payload(mapping, farmers_by_id) }
      end

      def pagination_values
        per_page = params[:per_page].presence || params[:limit].presence || DEFAULT_PER_PAGE
        per_page = per_page.to_i
        per_page = DEFAULT_PER_PAGE if per_page <= 0
        per_page = [per_page, MAX_PER_PAGE].min
        page = params[:page].to_i
        page = 1 if page <= 0
        [page, per_page]
      end

      def apply_search(scope)
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search].to_s.strip)}%"
        scope.left_joins(:vrp).where(
          "vrps.name ILIKE :term OR target_mappings.fco_name ILIKE :term OR " \
          "target_mappings.ics_name ILIKE :term OR target_mappings.village_name ILIKE :term OR " \
          "target_mappings.month_name ILIKE :term OR target_mappings.main_activity_name ILIKE :term OR " \
          "target_mappings.activity_name ILIKE :term",
          term: term
        )
      end

      def mapping_payload(mapping, farmers_by_id)
        farmer_ids = Array(mapping.afl_ids).map(&:to_s).compact_blank.uniq
        weekly_targets = mapping.weekly_target_values

        {
          id: mapping.id,
          jeevika_jankar_id: mapping.vrp_id,
          jeevika_jankar_name: mapping.vrp&.name,
          cc_name: mapping.vrp&.cluster_incharge,
          cluster_incharge: mapping.vrp&.cluster_incharge,
          cc_target: mapping.cc_target.to_i,
          fco_id: mapping.fco_id,
          fco_name: mapping.fco_name,
          ics_id: mapping.ics_id,
          ics_name: mapping.ics_name,
          village_id: mapping.village_id,
          village_name: mapping.village_name,
          month: mapping.month_name,
          completion_date: mapping.completion_date&.iso8601,
          main_activity: mapping.main_activity_name,
          sub_activity: mapping.activity_name,
          main_activity_type: target_main_activity_type(mapping),
          training_targets: {
            opg_training: mapping.opg_training_target,
            general_training_meeting: mapping.week_wise_opg_target,
            input_demo_inm: mapping.input_demo_inm_target,
            input_demo_pm: mapping.input_demo_pm_target,
            ffs: mapping.ffs_target
          },
          farmer_target: mapping.target_quantity,
          weekly_targets: { week_1: weekly_targets[0], week_2: weekly_targets[1], week_3: weekly_targets[2], week_4: weekly_targets[3] },
          farmer_count: farmer_ids.size,
          farmers: farmer_ids.map { |id| farmer_payload(id, farmers_by_id[id]) },
          created_at: mapping.created_at&.iso8601,
          updated_at: mapping.updated_at&.iso8601
        }
      end

      def farmer_payload(id, farmer)
        { id: id, farmer_name: farmer&.farmer_name, father_name: farmer&.father_name,
          tracenet_no: farmer&.tracenet_no, mobile_no: farmer&.mobile_no, village_name: farmer&.village_name }
      end

      def target_main_activity_type(mapping)
        settings = target_activity_type_settings
        main_key = mapping.main_activity_name.to_s.strip.downcase
        sub_key = mapping.activity_name.to_s.strip.downcase
        settings[:main][main_key].presence || settings[:main][sub_key].presence || settings[:sub][sub_key].presence || "Training"
      end

      def target_activity_type_settings
        return @target_activity_type_settings if defined?(@target_activity_type_settings)

        main = ModuleRecord.where(module_slug: "add-activity-group").order(created_at: :desc).each_with_object({}) do |record, values|
          next if record.data["status"].to_s.casecmp("Inactive").zero?
          name = (record.data["main_activity_name"].presence || record.data["activity_group_name"]).to_s.strip.downcase
          values[name] ||= record.data["main_activity_type"].presence || "Training" if name.present?
        end
        sub = ModuleRecord.where(module_slug: "add-vrp-activity").order(created_at: :desc).each_with_object({}) do |record, values|
          next if record.data["status"].to_s.casecmp("Inactive").zero?
          main_name = (record.data["main_activity"].presence || record.data["activity_group"]).to_s.strip.downcase
          sub_name = (record.data["sub_activity_name"].presence || record.data["activity_name"]).to_s.strip.downcase
          values[sub_name] ||= main[main_name] if sub_name.present? && main[main_name].present?
        end
        @target_activity_type_settings = { main: main, sub: sub }
      end
    end
  end
end
