class AssistantController < ApplicationController
  # Login is already enforced by ApplicationController#require_app_login.

  # POST /assistant/chat
  # Body: { "messages": [ { "role": "user"|"assistant", "content": "..." }, ... ] }
  # Returns: { "reply": "..." } or { "error": "..." }
  def chat
    messages = params[:messages]
    messages = messages.map { |message| message.respond_to?(:to_unsafe_h) ? message.to_unsafe_h : message } if messages.is_a?(Array)
    filters = params[:context].is_a?(ActionController::Parameters) ? params[:context].permit(*AssistantReports::FILTERS).to_h : {}

    messages = normalize_chat_messages(messages)
    context = AssistantContext.new(self, filters: filters)
    quick = AssistantQuickReply.new(context: context, filters: filters).call(messages)
    if quick
      render json: quick
    else
      reply = AssistantService.new.chat(messages, context: context)
      render json: { reply: reply }
    end
  rescue AssistantService::InvalidRequest => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue AssistantService::NotConfigured => e
    render json: { error: e.message }, status: :service_unavailable
  rescue AssistantService::ProviderTimeout => e
    render json: { error: e.message }, status: :gateway_timeout
  rescue AssistantService::ProviderError => e
    render json: { error: e.message }, status: :bad_gateway
  rescue StandardError => e
    Rails.logger.error("[assistant] request_id=#{request.request_id} error_class=#{e.class.name}")
    render json: { error: "Something went wrong. Please try again." }, status: :internal_server_error
  end

  def reports
    filters = params.permit(*AssistantReports::FILTERS).to_h
    render json: { reports: AssistantReports.catalog.map { |report| AssistantReports.link(report, filters) } }
  end

  def summary
    filters = params.permit(*AssistantReports::FILTERS).to_h
    data = AssistantContext.new(self, filters: filters).call([])
    rows = [["Scope", data[:scope]], ["Gender month", data[:month]], ["Farmers", data[:farmers]], ["Villages", data[:villages]], ["ICS", data[:ics]]]
    Array(data[:jj_gender_by_fco]).each do |row|
      rows << ["#{row[:fco]} active JJ male", row[:male]]
      rows << ["#{row[:fco]} active JJ female", row[:female]]
    end
    send_xlsx(headers: ["Metric", "Value"], rows: rows, filename: "project-summary-#{Date.current}.xlsx", sheet_name: "Project summary")
  end

  private

  def normalize_chat_messages(messages)
    raise AssistantService::InvalidRequest, "Please type a message." unless messages.is_a?(Array)
    cleaned = messages.last(AssistantService::MAX_HISTORY_MESSAGES).filter_map do |message|
      next unless message.is_a?(Hash) && %w[user assistant].include?(message["role"])
      content = message["content"].to_s.strip.first(AssistantService::MAX_MESSAGE_CHARACTERS)
      next if content.blank?
      { "role" => message["role"], "content" => content }
    end
    raise AssistantService::InvalidRequest, "Please type a message." if cleaned.empty?
    raise AssistantService::InvalidRequest, "The conversation must end with a message from you." unless cleaned.last["role"] == "user"
    cleaned
  end

end
