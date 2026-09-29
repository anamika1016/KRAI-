module Api
  module V1
    class TargetMappingsController < BaseController
      DEFAULT_PER_PAGE = 100
      MAX_PER_PAGE = 200
      SUMMARY_MODES = %w[main_activity sub_activity raw].freeze

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

      private

      def web_filtered_mappings
        controller = web_target_mappings_controller
        scope = controller.send(:filtered_visible_target_mappings)
        scope = apply_search(scope) if params[:search].present?
        scope.includes(:vrp, :vrp_ics_mapping).order("target_mappings.updated_at DESC").to_a
      end

      def web_target_mappings_controller
        controller = ::TargetMappingsController.new
        controller.request = request
        controller.params = normalized_web_params
        controller.instance_variable_set(:@current_app_user, current_api_user_payload)
        controller
      end

      # The app sends `fco=All` and `ics=All`; the web form omits those values.
      # Normalize both forms before using the web controller's filter methods.
      def normalized_web_params
        values = params.to_unsafe_h.deep_dup
        %w[main_activity sub_activity ics].each do |key|
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

        values["summary_mode"] = requested_summary_mode
        ActionController::Parameters.new(values)
      end

      def all_filter_value?(value)
        normalized = value.to_s.strip.downcase
        normalized.blank? || normalized == "all" || normalized.start_with?("all ")
      end

      def requested_summary_mode
        requested = params[:summary_mode].to_s.strip.downcase
        SUMMARY_MODES.include?(requested) ? requested : "main_activity"
      end

      def summary_records(mappings, mode)
        controller = web_target_mappings_controller
        controller.instance_variable_set(:@target_summary_mode, mode)
        controller.send(:target_mapping_summary_rows, mappings)
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
