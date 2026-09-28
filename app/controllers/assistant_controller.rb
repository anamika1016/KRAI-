class AssistantController < ApplicationController
  # Login is already enforced by ApplicationController#require_app_login.

  # POST /assistant/chat
  # Body: { "messages": [ { "role": "user"|"assistant", "content": "..." }, ... ] }
  # Returns: { "reply": "..." } or { "error": "..." }
  def chat
    messages = params[:messages]
    messages = messages.map(&:to_unsafe_h) if messages.respond_to?(:map)

    reply = AssistantService.new.chat(messages)
    render json: { reply: reply }
  rescue AssistantService::InvalidRequest => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue AssistantService::NotConfigured => e
    render json: { error: e.message }, status: :service_unavailable
  rescue AssistantService::ProviderTimeout => e
    render json: { error: e.message }, status: :gateway_timeout
  rescue AssistantService::ProviderError => e
    render json: { error: e.message }, status: :bad_gateway
  rescue StandardError
    render json: { error: "Something went wrong. Please try again." }, status: :internal_server_error
  end
end
