require "net/http"
require "uri"

class OtpSmsSender
  DEFAULT_API_URL = "https://sms.yoursmsbox.com/api/sendhttp.php".freeze
  DEFAULT_AUTH_KEY = "37317061706c39353312".freeze
  TEMPLATE_ID = "1707178065575161459".freeze
  HEADER = "PLOAPL".freeze
  BRAND_NAME = "Ploughman Agro Private Limited (PAPL)".freeze
  DEFAULT_TIMEOUT_SECONDS = 10

  Result = Struct.new(:success, :message, :response_code, :response_body, keyword_init: true) do
    def success?
      success
    end
  end

  attr_reader :mobile_number, :otp

  def initialize(mobile_number, otp)
    @mobile_number = mobile_number.to_s
    @otp = otp.to_s
  end

  def deliver
    if sms_auth_key.blank?
      Rails.logger.warn("[OTP SMS] SMS auth key is not configured; OTP was not sent.")
      return Result.new(success: false, message: "SMS auth key is not configured.")
    end

    deliver_to_gateway
  end

  private

  def deliver_to_gateway
    uri = URI.parse(sms_api_url)
    existing_query = uri.query.present? ? URI.decode_www_form(uri.query).to_h : {}
    uri.query = URI.encode_www_form(existing_query.merge(payload))

    response = request_with_redirects(uri)
    success = response.is_a?(Net::HTTPSuccess)
    log_gateway_response(response, success)

    Result.new(
      success: success,
      message: success ? "Gateway accepted OTP request." : "Gateway returned #{response.code}.",
      response_code: response.code,
      response_body: response.body
    )
  rescue StandardError => e
    Rails.logger.error("[OTP SMS] Gateway error: #{e.class} #{e.message}")
    Result.new(success: false, message: "#{e.class}: #{e.message}")
  end

  def sms_api_url
    ENV["SMS_API_URL"].presence || DEFAULT_API_URL
  end

  def request_with_redirects(uri, limit = 3)
    raise "SMS gateway redirected too many times." if limit.zero?

    response = http_get(uri)
    if response.is_a?(Net::HTTPRedirection)
      redirect_uri = URI.parse(response["location"].to_s)
      redirect_uri = uri.merge(response["location"].to_s) if redirect_uri.relative?
      Rails.logger.info("[OTP SMS] Gateway redirected to #{redirect_uri}")
      return request_with_redirects(redirect_uri, limit - 1)
    end

    response
  end

  def http_get(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout_seconds
    http.read_timeout = timeout_seconds

    http.request(Net::HTTP::Get.new(uri.request_uri))
  end

  def sms_auth_key
    ENV["SMS_AUTH_KEY"].presence || DEFAULT_AUTH_KEY
  end

  def timeout_seconds
    seconds = ENV.fetch("SMS_API_TIMEOUT", DEFAULT_TIMEOUT_SECONDS).to_i
    seconds.positive? ? seconds : DEFAULT_TIMEOUT_SECONDS
  end

  def log_gateway_response(response, success)
    log_message = "[OTP SMS] Gateway response: #{response.code} #{response.body}"
    success ? Rails.logger.info(log_message) : Rails.logger.warn(log_message)
  end

  def payload
    {
      authkey: sms_auth_key,
      mobiles: provider_mobile_number,
      message: message,
      sender: HEADER,
      route: 2,
      country: 0,
      DLT_TE_ID: TEMPLATE_ID,
      response: "json"
    }
  end

  def provider_mobile_number
    digits = mobile_number.gsub(/\D/, "")
    return "91#{digits}" if digits.match?(/\A[6-9]\d{9}\z/)

    digits
  end

  def message
    "#{BRAND_NAME}: Your login OTP is #{otp}. Do not share it with anyone."
  end
end
