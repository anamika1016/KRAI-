module Api
  module V1
    class OtherTargetsController < FarmerTargetBaseController
      MODULE_SLUG = "other-target".freeze
      RESOURCE_TITLE = "Other Target".freeze
      RESOURCE_KEY = "other_targets".freeze
      PARAM_KEY = :other_target

      def index
        render_list(RESOURCE_KEY)
      end

      def show
        render_show
      end

      def create
        render_create
      end

      def form_options
        render_form_options
      end
    end
  end
end
