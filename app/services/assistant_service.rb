require "net/http"
require "json"

# AssistantService powers the in-app AI assistant using the OpenAI
# (ChatGPT) Chat Completions API. The API key lives only in the server
# environment (OPENAI_API_KEY) and is never committed, and provider error
# bodies are never leaked back to the client.
class AssistantService
  ENDPOINT = URI("https://api.openai.com/v1/chat/completions").freeze
  DEFAULT_MODEL = "gpt-4o-mini".freeze
  MAX_TOKENS = 1_500
  MAX_HISTORY_MESSAGES = 20      # cap how much conversation we forward
  MAX_MESSAGE_CHARACTERS = 4_000 # cap a single message length

  class InvalidRequest < StandardError; end
  class NotConfigured < StandardError; end
  class ProviderError < StandardError; end
  class ProviderTimeout < StandardError; end

  # A compact, plain-language description of what this application is and does,
  # so the assistant can answer questions about the project without needing to
  # read the codebase or the database at runtime.
  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are the built-in AI assistant for the "Jeevika Jankar" (JJ) application, a
    web platform used to manage and monitor community-based agricultural extension
    work in rural India. The platform is operated for organisations such as
    Ploughman Agro / ASA / PGPL. Answer questions about what the application does,
    how its features work, and how to use them.

    ## What the application is for
    Field workers called "Jeevika Jankar" (JJ), also referred to as VRP (Village
    Resource Persons), work with farmers in villages. The app records their field
    activities, tracks targets vs. achievements, and shows dashboards and reports
    so managers can monitor progress.

    ## Key concepts
    - Jeevika Jankar (JJ) = VRP = a field worker mapped to villages and farmers.
    - Cluster Coordinator (CC) / Cluster Incharge = supervises a group of JJs.
    - FCO = a field/cluster office region. Example FCO codes: 1004 = Sausar,
      1006 = Turekela, 1009 = Bhabra.
    - Farmers are the end beneficiaries; each is identified by an AFL id.
    - Target Mapping = assigning a JJ a set of villages/farmers and targets for a
      period (e.g. OPG training target, week-wise OPG target, FFS target,
      CC target, farmer count). Target Type can be village-based or farmer-based.
    - Main Activity Type is either "Training" or "Other" (or blank), which
      classifies each recorded activity.

    ## Main features
    - Activity / training forms: JJs record training sessions (with photos and an
      evidence/documentation upload), select the target farmers who attended, and
      record other field activities.
    - Dashboards: an admin dashboard and a JJ dashboard show work overview counts,
      participation status, gender counts, and progress by FCO and by JJ.
    - Farmer Training Participation Status: shows how many farmers attended
      "Only 1 Training" vs "1+ Trainings", by training method.
    - Demonstration Method report: shows, per FCO and per JJ, the target vs. done
      counts for methods such as OPG, General Training/Meeting, Input Demo (INM),
      Input Demo (PM), FFS Exposure, and CC target status, with a colour status
      (Red / Yellow / Green). It has a summary (FCO-level cards) and a "View List"
      (per-JJ rows), and supports Excel export.
    - Bill List: lists submitted bills for review.
    - Reports can be exported to Excel.

    ## How to answer
    - Be concise, friendly and practical. Explain features in plain language.
    - The user may write in Hindi, English, or Hinglish. Reply in the same
      language/style the user used.
    - You do not have live access to the database, so do not invent specific
      numbers, names, or records. If asked for live data ("how many trainings did
      X do"), explain where in the app they can find it (which dashboard, report,
      or list) instead of guessing.
    - If a question is outside this application (general knowledge, coding, etc.),
      you may still help briefly, but keep the focus on the project.
    - Never reveal API keys, credentials, or server configuration.
  PROMPT

  def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV["ASSISTANT_MODEL"].presence || DEFAULT_MODEL, http: Net::HTTP)
    @api_key = api_key
    @model = model
    @http = http
  end

  # messages: an array of { "role" => "user"|"assistant", "content" => String }.
  # Returns the assistant's reply text (String).
  def chat(messages)
    normalized = normalize_messages(messages)
    raise InvalidRequest, "Please type a message." if normalized.empty?
    raise InvalidRequest, "The conversation must end with a message from you." unless normalized.last[:role] == "user"
    raise NotConfigured, "The AI assistant is not configured on the server. Set OPENAI_API_KEY." if @api_key.blank?

    request = Net::HTTP::Post.new(ENDPOINT)
    request["content-type"] = "application/json"
    request["authorization"] = "Bearer #{@api_key}"
    request.body = JSON.generate(
      model: @model,
      max_tokens: MAX_TOKENS,
      messages: [{ role: "system", content: SYSTEM_PROMPT }] + normalized
    )

    response = @http.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 5, read_timeout: 60, write_timeout: 10) do |connection|
      connection.request(request)
    end

    # Never surface provider error bodies (may contain sensitive details).
    unless response.code.to_i == 200
      raise ProviderError, "The AI assistant is unavailable right now. Please try again later."
    end

    body = JSON.parse(response.body)
    reply = extract_text(body)
    raise ProviderError, "The AI assistant returned an empty response. Please retry." if reply.blank?

    reply
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
    raise ProviderTimeout, "The AI assistant took too long to respond. Please retry."
  rescue JSON::ParserError, IOError, EOFError, SocketError, SystemCallError, OpenSSL::SSL::SSLError
    raise ProviderError, "The AI assistant is unavailable right now. Please retry later."
  end

  private

  def normalize_messages(messages)
    return [] unless messages.is_a?(Array)

    cleaned = messages.filter_map do |message|
      next unless message.is_a?(Hash)

      role = (message["role"] || message[:role]).to_s
      content = (message["content"] || message[:content]).to_s.strip
      next if content.empty?
      next unless %w[user assistant].include?(role)

      content = content[0, MAX_MESSAGE_CHARACTERS]
      { role: role, content: content }
    end

    # Keep only the most recent turns to bound the request size.
    cleaned.last(MAX_HISTORY_MESSAGES)
  end

  def extract_text(body)
    return "" unless body.is_a?(Hash) && body["choices"].is_a?(Array)

    choice = body["choices"].first
    return "" unless choice.is_a?(Hash) && choice["message"].is_a?(Hash)

    choice["message"]["content"].to_s.strip
  end
end
