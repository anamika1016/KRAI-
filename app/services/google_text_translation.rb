require "net/http"
require "json"
require "cgi"

class GoogleTextTranslation
  LANGUAGES = { "en" => "English", "hi" => "Hindi", "mr" => "Marathi", "or" => "Odia", "gu" => "Gujarati" }.freeze
  ENDPOINT = URI("https://translation.googleapis.com/language/translate/v2").freeze
  MAX_TEXTS = 100
  MAX_CHARACTERS = 5_000

  class InvalidRequest < StandardError; end
  class NotConfigured < StandardError; end
  class ProviderError < StandardError; end
  class ProviderTimeout < StandardError; end

  def initialize(api_key: ENV["GOOGLE_TRANSLATE_API_KEY"], http: Net::HTTP)
    @api_key = api_key
    @http = http
  end

  def translate(q:, target:, source: "en")
    texts = q.is_a?(String) ? [q] : q
    unless texts.is_a?(Array) && texts.size.between?(1, MAX_TEXTS) && texts.all? { |text| text.is_a?(String) && text.present? }
      raise InvalidRequest, "q must be a nonblank string or an array of 1–#{MAX_TEXTS} nonblank strings."
    end
    raise InvalidRequest, "Maximum #{MAX_CHARACTERS} characters per request." if texts.sum(&:length) > MAX_CHARACTERS
    unless LANGUAGES.key?(source) && LANGUAGES.key?(target)
      raise InvalidRequest, "source and target must be one of: #{LANGUAGES.keys.join(', ')}."
    end
    return texts.map { |text| { text: text, translated_text: text } } if source == target
    raise NotConfigured, "Translation is not configured on the server. Set GOOGLE_TRANSLATE_API_KEY." if @api_key.blank?

    # Deduplicate within this request; do not store potentially private text in a shared cache.
    unique_texts = texts.uniq
    request = Net::HTTP::Post.new(ENDPOINT)
    request["Content-Type"] = "application/json"
    request["X-Goog-Api-Key"] = @api_key
    request.body = JSON.generate(q: unique_texts, source: source, target: target, format: "text")
    response = @http.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 3, read_timeout: 8, write_timeout: 5) do |connection|
      connection.request(request)
    end
    # Never return provider error bodies, credentials or submitted text in errors.
    raise ProviderError, "Google translation failed. Check server credentials, billing and quota." unless response.code.to_i == 200

    body = JSON.parse(response.body)
    translated = body.is_a?(Hash) && body["data"].is_a?(Hash) ? body["data"]["translations"] : nil
    unless translated.is_a?(Array) && translated.size == unique_texts.size && translated.all? { |item| item.is_a?(Hash) && item["translatedText"].is_a?(String) }
      raise ProviderError, "Google returned an invalid translation response."
    end
    lookup = unique_texts.zip(translated.map { |item| CGI.unescapeHTML(item["translatedText"]) }).to_h
    texts.map { |text| { text: text, translated_text: lookup.fetch(text) } }
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
    raise ProviderTimeout, "Translation timed out. Please retry."
  rescue JSON::ParserError, IOError, EOFError, SocketError, SystemCallError, OpenSSL::SSL::SSLError
    raise ProviderError, "Translation service is unavailable. Please retry later."
  end
end
