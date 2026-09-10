module Api
  module V1
    class TranslationsController < BaseController
      rate_limit to: 60, within: 1.minute, only: :create,
        by: -> { "#{current_api_user.class.name}:#{current_api_user.id}" },
        with: -> { render json: { success: false, code: "rate_limited", message: "Too many translation requests. Try again in a minute." }, status: :too_many_requests }

      def languages
        render json: { success: true, source: "en", languages: GoogleTextTranslation::LANGUAGES.map { |code, name| { code: code, name: name } } }
      end

      def create
        source = params.fetch(:source, "en")
        target = params[:target]
        translations = GoogleTextTranslation.new.translate(q: params[:q], source: source, target: target)
        render json: { success: true, source: source, target: target, translations: translations }
      rescue GoogleTextTranslation::InvalidRequest => error
        translation_error(error, "invalid_request", :unprocessable_entity)
      rescue GoogleTextTranslation::NotConfigured => error
        translation_error(error, "translation_not_configured", :service_unavailable)
      rescue GoogleTextTranslation::ProviderTimeout => error
        translation_error(error, "translation_timeout", :gateway_timeout)
      rescue GoogleTextTranslation::ProviderError => error
        translation_error(error, "translation_unavailable", :bad_gateway)
      end

      private

      def translation_error(error, code, status)
        render json: { success: false, code: code, message: error.message }, status: status
      end
    end
  end
end
