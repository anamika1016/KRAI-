module Api
  module V1
    class FarmerTargetBaseController < BaseController
      private

      def current_app_user
        current_api_user_payload
      end

      def farmer_target_api(module_slug = self.class::MODULE_SLUG)
        @farmer_target_apis ||= {}
        @farmer_target_apis[module_slug] ||= FarmerTargetApi.new(
          current_app_user: current_app_user,
          module_slug: module_slug,
          exclude_record_id: params[:id]
        )
      end

      def render_list(resource_key)
        records = farmer_target_api.list
        render json: {
          success: true,
          message: "#{self.class::RESOURCE_TITLE} list fetched successfully.",
          resource_key => records,
          count: records.size
        }, status: :ok
      end

      def render_show
        record = farmer_target_api.find(params[:id])
        unless record
          return render json: { success: false, message: "#{self.class::RESOURCE_TITLE} record not found." }, status: :not_found
        end

        body = { success: true }
        body[self.class::RESOURCE_KEY.singularize] = farmer_target_api.record_payload(record)
        render json: body, status: :ok
      end

      def render_create
        merge_json_body_params!
        attrs = create_attrs
        result = farmer_target_api.create(attrs)

        unless result[:success]
          return render json: {
            success: false,
            message: "#{self.class::RESOURCE_TITLE} save failed.",
            errors: result[:errors]
          }, status: :unprocessable_entity
        end

        body = {
          success: true,
          message: "#{self.class::RESOURCE_TITLE} saved successfully."
        }
        body[self.class::RESOURCE_KEY.singularize] = farmer_target_api.record_payload(result[:record])
        render json: body, status: :created
      end

      def render_form_options
        render json: {
          success: true,
          options: farmer_target_api.form_options
        }, status: :ok
      end

      # Other-target forms use the same target mapping and farmer controls as
      # the web form.  These endpoints intentionally live in the common base
      # controller so Seed Distribution and PAPL360 receive the exact same
      # conditions without changing their web pages.
      def render_target_form_data
        options = farmer_target_api.form_options
        mappings = filter_target_form_mappings(Array(options[:target_mappings]))
        farmers = mappings.flat_map { |mapping| Array(mapping[:farmers]) }.uniq { |farmer| farmer[:id].to_s }
        completed_ids = mappings.flat_map { |mapping| Array(mapping[:completed_farmer_ids]) }.map(&:to_s).uniq
        available = farmers.reject { |farmer| completed_ids.include?(farmer[:id].to_s) }

        render json: {
          success: true,
          message: "#{self.class::RESOURCE_TITLE} form data fetched successfully.",
          filters: target_form_filter_payload,
          options: options.merge(target_mappings: mappings),
          target_mappings: mappings,
          farmers: farmers,
          available_farmers: available,
          completed_farmer_ids: completed_ids,
          farmer_count: farmers.size,
          available_farmer_count: available.size
        }, status: :ok
      end

      def render_target_form_farmers(mapped: false)
        options = farmer_target_api.form_options
        mappings = filter_target_form_mappings(Array(options[:target_mappings]))
        farmers = mappings.flat_map { |mapping| Array(mapping[:farmers]) }.uniq { |farmer| farmer[:id].to_s }
        completed_ids = mappings.flat_map { |mapping| Array(mapping[:completed_farmer_ids]) }.map(&:to_s).uniq
        rows = mapped ? farmers.map { |farmer| farmer.merge(is_completed: completed_ids.include?(farmer[:id].to_s), is_available: !completed_ids.include?(farmer[:id].to_s)) } :
          farmers.reject { |farmer| completed_ids.include?(farmer[:id].to_s) }
        key = mapped ? :mapped_farmers : :farmers
        render json: {
          success: true,
          message: "#{self.class::RESOURCE_TITLE} farmer list fetched successfully.",
          filters: target_form_filter_payload,
          target_mapping_ids: mappings.map { |mapping| mapping[:target_mapping_id] }.compact.uniq,
          key => rows,
          count: rows.size,
          all_farmer_count: farmers.size,
          completed_farmer_ids: completed_ids
        }, status: :ok
      end

      def create_attrs
        raw = params[self.class::PARAM_KEY].presence || params[:module_record].presence || params
        if raw.respond_to?(:to_unsafe_h)
          raw.to_unsafe_h.except("controller", "action", "format", "token", "authenticity_token", self.class::PARAM_KEY.to_s, "module_record")
        else
          Hash(raw)
        end
      end

      def filter_target_form_mappings(mappings)
        mappings.select do |mapping|
          target_form_match?(mapping[:month], params[:month]) &&
            target_form_fco_match?(mapping) &&
            target_form_match?(mapping[:ics], params[:ics].presence || params[:ics_name]) &&
            target_form_match?(mapping[:village], params[:village].presence || params[:village_name]) &&
            target_form_match?(mapping[:main_activity], params[:main_activity].presence || params[:training_topic]) &&
            target_form_match?(mapping[:sub_activity], params[:sub_activity].presence || params[:training_subject]) &&
            target_form_match?(mapping[:target_mapping_id], params[:target_mapping_id])
        end
      end

      def target_form_fco_match?(mapping)
        requested = [params[:fco_id], params[:fpo_id], params[:fco_name], params[:fpo_name], params[:fco], params[:fpo]].compact_blank
        return true if requested.blank? || requested.any? { |value| value.to_s.strip.casecmp("all").zero? }

        actual = [mapping[:fco_id], mapping[:fpo_id], mapping[:fco_name], mapping[:fpo_name], mapping[:department]].compact_blank
        requested.any? { |expected| actual.any? { |value| target_form_fco_value?(value, expected) } }
      end

      def target_form_fco_value?(actual, expected)
        normalise = ->(value) { value.to_s.downcase.gsub(/\Afco\s*(?:-\s*c)?\s*[-:]?\s*/i, "").squish }
        normalise.call(actual) == normalise.call(expected)
      end

      def target_form_match?(actual, expected)
        expected.blank? || expected.to_s.strip.casecmp("all").zero? || actual.to_s.strip.casecmp(expected.to_s.strip).zero?
      end

      def target_form_filter_payload
        %i[month fco_id fco_name ics village main_activity sub_activity target_mapping_id].index_with { |key| params[key] }
      end

      def merge_json_body_params!
        return if request.content_type.to_s.include?("multipart")
        return unless request.body.present?

        body = request.raw_post.to_s
        return if body.blank?

        json = JSON.parse(body)
        return unless json.is_a?(Hash)

        json.each { |key, value| params[key] = value if params[key].blank? }
      rescue JSON::ParserError
        nil
      end
    end
  end
end
