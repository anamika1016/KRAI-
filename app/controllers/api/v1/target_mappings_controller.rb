module Api
  module V1
    class TargetMappingsController < BaseController
      DEFAULT_LIMIT = 100
      MAX_LIMIT = 200

      def recent
        mappings = filtered_mappings
        farmer_ids = mappings.flat_map { |mapping| Array(mapping.afl_ids) }.map(&:to_s).compact_blank.uniq
        farmers_by_id = Afl.where(id: farmer_ids).index_by { |farmer| farmer.id.to_s }

        render json: {
          success: true,
          message: "Recent target mappings fetched successfully.",
          target_mappings: mappings.map { |mapping| mapping_payload(mapping, farmers_by_id) },
          count: mappings.size
        }, status: :ok
      end

      private

      def filtered_mappings
        scope = visible_mappings.includes(:vrp, :vrp_ics_mapping)
        scope = scope.where("LOWER(month_name) = ?", params[:month].to_s.strip.downcase) if params[:month].present?
        scope = apply_search(scope) if params[:search].present?
        scope.order("target_mappings.updated_at DESC").limit(requested_limit).to_a
      end

      def visible_mappings
        payload = current_api_user_payload
        return TargetMapping.all if payload["user_type"].to_s.casecmp("admin").zero?
        return TargetMapping.where(vrp_id: payload["id"]) if payload["record_type"] == "Vrp"

        TargetMapping.where(created_by_type: payload["record_type"], created_by_id: payload["id"])
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

      def requested_limit
        limit = params[:limit].to_i
        limit = DEFAULT_LIMIT if limit <= 0
        [limit, MAX_LIMIT].min
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
          training_targets: {
            opg_training: mapping.opg_training_target,
            general_training_meeting: mapping.week_wise_opg_target,
            input_demo_inm: mapping.input_demo_inm_target,
            input_demo_pm: mapping.input_demo_pm_target,
            ffs: mapping.ffs_target
          },
          farmer_target: mapping.target_quantity,
          weekly_targets: {
            week_1: weekly_targets[0],
            week_2: weekly_targets[1],
            week_3: weekly_targets[2],
            week_4: weekly_targets[3]
          },
          farmer_count: farmer_ids.size,
          farmers: farmer_ids.map { |id| farmer_payload(id, farmers_by_id[id]) },
          created_at: mapping.created_at&.iso8601,
          updated_at: mapping.updated_at&.iso8601
        }
      end

      def farmer_payload(id, farmer)
        {
          id: id,
          farmer_name: farmer&.farmer_name,
          father_name: farmer&.father_name,
          tracenet_no: farmer&.tracenet_no,
          mobile_no: farmer&.mobile_no,
          village_name: farmer&.village_name
        }
      end
    end
  end
end
