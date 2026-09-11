require "test_helper"

class GoogleTextTranslationTest < ActiveSupport::TestCase
  class FakeHttp
    attr_reader :request_data, :options
    attr_accessor :body, :code, :failure
    def initialize
      @code = "200"
      @body = { data: { translations: [{ translatedText: "डैशबोर्ड" }, { translatedText: "प्रशिक्षण &amp; फॉर्म" }] } }.to_json
    end
    def start(host, port, **options)
      raise failure if failure
      @options = options
      yield self
    end
    def request(request)
      @request_data = request
      Struct.new(:code, :body).new(code, body)
    end
  end

  test "Google batch deduplicates while preserving original order and uses server credential" do
    http = FakeHttp.new
    service = GoogleTextTranslation.new(api_key: "test-only-key", http: http)
    rows = service.translate(q: ["Dashboard", "Training", "Dashboard"], target: "hi")
    assert_equal ["डैशबोर्ड", "प्रशिक्षण & फॉर्म", "डैशबोर्ड"], rows.map { |r| r[:translated_text] }
    assert_equal ["Dashboard", "Training"], JSON.parse(http.request_data.body)["q"]
    assert_equal "test-only-key", http.request_data["X-Goog-Api-Key"]
    assert_nil http.request_data["Authorization"]
    assert_equal true, http.options[:use_ssl]
    assert_equal 8, http.options[:read_timeout]
  end

  test "missing key, invalid input and oversized batches are explicit errors" do
    service = GoogleTextTranslation.new(api_key: nil)
    assert_raises(GoogleTextTranslation::NotConfigured) { service.translate(q: "Dashboard", target: "hi") }
    [nil, [], [1], [" "], ["x"] * 101, ["x" * 5001]].each do |q|
      assert_raises(GoogleTextTranslation::InvalidRequest) { service.translate(q: q, target: "hi") }
    end
    assert_raises(GoogleTextTranslation::InvalidRequest) { service.translate(q: "Dashboard", target: "invalid") }
  end

  test "upstream failures and timeouts do not expose provider bodies" do
    http = FakeHttp.new
    service = GoogleTextTranslation.new(api_key: "test-only-key", http: http)
    http.code = "401"
    http.body = "sensitive provider details"
    error = assert_raises(GoogleTextTranslation::ProviderError) { service.translate(q: "Dashboard", target: "hi") }
    refute_includes error.message, "sensitive"
    http.code = "200"
    assert_raises(GoogleTextTranslation::ProviderError) { service.translate(q: "Dashboard", target: "hi") }
    http.body = '{"data":{"translations":[]}}'
    assert_raises(GoogleTextTranslation::ProviderError) { service.translate(q: "Dashboard", target: "hi") }
    http.failure = Net::ReadTimeout.new
    assert_raises(GoogleTextTranslation::ProviderTimeout) { service.translate(q: "Dashboard", target: "hi") }
  end
end
