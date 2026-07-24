module Api
  module V1
    class JeevikaJankarDashboardController < BaseController
      def show
        vrp = current_dashboard_vrp
        return render json: { success: false, message: "Valid Jeevika Jankar login required." }, status: :unprocessable_entity unless vrp

        targets = TargetMapping.where(vrp_id: vrp.id).order(:month_name, :main_activity_name, :activity_name, :id).to_a
        months = targets.filter_map { |target| target.month_name.to_s.strip.presence }.uniq
        selected_month = params[:month].presence || default_month(months)
        targets = targets.select { |target| same_text?(target.month_name, selected_month) } if selected_month.present?
        progress = targets.map { |target| progress_payload(target) }
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

      private

      def current_dashboard_vrp
        user = current_api_user_payload
        return Vrp.find_by(id: user["id"]) if user["record_type"] == "Vrp"
        return Vrp.find_by(id: params[:vrp_id]) if user["user_type"].to_s.casecmp("admin").zero? && params[:vrp_id].present?
      end

      def default_month(months)
        current = Date.current.strftime("%B")
        months.find { |month| same_text?(month, current) } || months.last
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
