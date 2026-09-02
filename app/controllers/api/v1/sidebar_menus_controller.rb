module Api
  module V1
    class SidebarMenusController < BaseController
      include ApplicationHelper

      def index
        render json: cached_sidebar_payload, status: :ok
      end

      private

      def current_app_user
        current_api_user_payload
      end

      def cached_sidebar_payload
        Rails.cache.fetch(sidebar_cache_key, expires_in: 10.minutes, race_condition_ttl: 30.seconds) do
          {
            success: true,
            message: "Sidebar menu access fetched successfully.",
            user: current_api_user_payload,
            sidebar_sections: sidebar_sections.map { |section| section_payload(section) }
          }
        end
      rescue StandardError => error
        Rails.logger.warn("Sidebar menu cache skipped: #{error.class}: #{error.message}")
        {
          success: true,
          message: "Sidebar menu access fetched successfully.",
          user: current_api_user_payload,
          sidebar_sections: sidebar_sections.map { |section| section_payload(section) }
        }
      end

      def sidebar_cache_key
        access_scope = ModuleRecord.where(module_slug: "access-control")
        user_scope = ModuleRecord.where(module_slug: "new-user")
        user_key = current_api_user_payload.slice("id", "user_id", "username", "user_name", "user_type").sort.to_h
        [
          "api-v1-sidebar-menus",
          user_key,
          access_scope.maximum(:updated_at).to_i,
          access_scope.maximum(:id).to_i,
          access_scope.count,
          user_scope.maximum(:updated_at).to_i,
          user_scope.maximum(:id).to_i,
          user_scope.count
        ].to_json
      end

      def section_payload(section)
        {
          title: section[:title],
          icon: section[:icon],
          menus: section[:links].map { |link| menu_payload(link) }
        }
      end

      def menu_payload(link)
        label, type, target = link
        {
          name: label,
          key: sidebar_access_key(link),
          type: type.to_s,
          target: target.to_s
        }
      end
    end
  end
end
