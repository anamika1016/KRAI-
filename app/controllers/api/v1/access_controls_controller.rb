# frozen_string_literal: true

module Api
  module V1
    class AccessControlsController < BaseController
      ACCESS_CONTROL_SLUG = "access-control".freeze

      def index
        records = access_control_records
        records = filter_by_status(records)
        records = filter_by_search(records)

        render json: {
          success: true,
          message: "Access Control List fetched successfully.",
          filters: { search: params[:search].presence || params[:q].presence, status: params[:status] },
          access_controls: records.map { |record| access_control_payload(record) },
          count: records.size
        }, status: :ok
      end

      def show
        record = ModuleRecord.find_by(id: params[:id], module_slug: ACCESS_CONTROL_SLUG)
        return render json: { success: false, message: "Access Control record not found." }, status: :not_found unless record

        render json: {
          success: true,
          message: "Access Control details fetched successfully.",
          access_control: access_control_payload(record)
        }, status: :ok
      end

      private

      def access_control_records
        ModuleRecord.where(module_slug: ACCESS_CONTROL_SLUG).order(updated_at: :desc, id: :desc).to_a
      end

      def filter_by_status(records)
        return records if params[:status].blank?

        records.select { |record| same_text?(record.data["status"].presence || "Active", params[:status]) }
      end

      def filter_by_search(records)
        query = (params[:search].presence || params[:q].presence).to_s.downcase.strip
        return records if query.blank?

        records.select do |record|
          data = record.data
          searchable = [
            data["stakeholder"], data["stakeholder_name"], data["stakeholder_role"],
            data["role_name"], data["role"], data["jeevika_jankar_type"], data["vrp_type"],
            data["module_names"], data["sub_module_names"], data["status"]
          ].flatten.compact.join(" ").downcase
          searchable.include?(query)
        end
      end

      def access_control_payload(record)
        data = record.data
        {
          id: record.id,
          stakeholder: data["stakeholder"].presence || data["stakeholder_name"].presence || "-",
          stakeholder_role: data["stakeholder_role"].presence || data["stakeholder_person_type"].presence || "-",
          role_name: data["role_name"].presence || data["role"].presence || "-",
          jeevika_jankar_type: data["jeevika_jankar_type"].presence || data["vrp_type"].presence || data["select_vrp_type"].presence || "-",
          module_names: array_value(data["module_names"].presence || data["module_name"]),
          sub_module_names: array_value(data["sub_module_names"].presence || data["sub_module_name"]),
          permissions: {
            can_view: permission_enabled?(data["can_view"], default: true),
            can_create: permission_enabled?(data["can_create"]),
            can_edit: permission_enabled?(data["can_edit"]),
            can_delete: permission_enabled?(data["can_delete"])
          },
          status: data["status"].presence || "Active",
          created_at: record.created_at&.iso8601,
          updated_at: record.updated_at&.iso8601
        }
      end

      def array_value(value)
        Array(value).flat_map { |item| item.to_s.split(",") }.map(&:strip).reject(&:blank?).uniq
      end

      def permission_enabled?(value, default: false)
        return default if value.blank?

        ActiveModel::Type::Boolean.new.cast(value) || %w[yes allowed].include?(value.to_s.downcase.strip)
      end

      def same_text?(left, right)
        left.to_s.strip.casecmp(right.to_s.strip).zero?
      end
    end
  end
end
