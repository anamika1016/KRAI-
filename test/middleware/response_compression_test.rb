require "test_helper"
require "stringio"
require "zlib"

class ResponseCompressionTest < ActiveSupport::TestCase
  test "configured middleware round trips HTML JSON and assets without changing content" do
    {
      "text/html; charset=utf-8" => "<html><body>#{'किसान Training 42 ' * 1000}</body></html>",
      "application/json" => { target: 42, achieved: 12, pending: 30, records: [ { name: "Farmer", visible: true } ] }.to_json,
      "text/css" => ".record { display: table-row; }\n" * 1000,
      "text/javascript" => "const target = 42;\n" * 1000
    }.each do |content_type, original|
      status, headers, body = response(original, content_type: content_type, encoding: "gzip")
      assert_equal 200, status
      assert_equal "gzip", headers["content-encoding"]
      assert_includes headers["vary"], "Accept-Encoding"
      compressed = consume(body)
      assert_equal original.b, Zlib::GzipReader.new(StringIO.new(compressed)).read.b
    end
  end

  test "clients without gzip keep their original response" do
    original = "Original page"
    _, headers, body = response(original, content_type: "text/html")
    assert_nil headers["content-encoding"]
    assert_equal original, consume(body)
  end

  test "HEAD and empty responses retain their empty body" do
    _, headers, body = response("", content_type: "text/html", encoding: "gzip", request_method: "HEAD",
      extra_headers: { "content-length" => "123" })
    assert_nil headers["content-encoding"]
    assert_equal "", consume(body)
    _, headers, body = response("", content_type: "application/json", encoding: "gzip")
    assert_nil headers["content-encoding"]
    assert_equal "", consume(body)
  end

  test "binary exports PDF and images are not recompressed" do
    [ XlsxExporter::MIME_TYPE, "application/zip", "application/pdf", "image/png", "image/jpeg" ].each do |content_type|
      original = "binary\x00content".b
      _, headers, body = response(original, content_type: content_type, encoding: "gzip")
      assert_nil headers["content-encoding"]
      assert_equal original, consume(body)
    end
  end

  test "range requests and partial text responses retain their original bytes" do
    [ [ 206, nil ], [ 200, "bytes=0-10" ] ].each do |status, range|
      original = "partial content"
      actual_status, headers, body = response(original, content_type: "text/css", encoding: "gzip", status: status, range: range)
      assert_equal status, actual_status
      assert_nil headers["content-encoding"]
      assert_equal original, consume(body)
    end
  end

  test "existing content encoding and no-transform responses are preserved" do
    [ { "content-encoding" => "br" }, { "cache-control" => "private, no-transform" } ].each do |extra_headers|
      original = "existing representation"
      _, headers, body = response(original, content_type: "text/html", encoding: "gzip", extra_headers: extra_headers)
      if extra_headers.key?("content-encoding")
        assert_equal extra_headers["content-encoding"], headers["content-encoding"]
      else
        assert_nil headers["content-encoding"]
      end
      assert_equal original, consume(body)
    end
  end

  private

  def response(original, content_type:, encoding: nil, status: 200, range: nil, extra_headers: {}, request_method: "GET")
    middleware = Rails.application.middleware.find { |entry| entry.klass == Rack::Deflater }
    assert middleware, "Response compression must be present in the real application stack"
    app = ->(_env) { [ status, { "content-type" => content_type, "content-length" => original.bytesize.to_s }.merge(extra_headers), [ original ] ] }
    env = Rack::MockRequest.env_for("/page", method: request_method)
    env["HTTP_ACCEPT_ENCODING"] = encoding if encoding
    env["HTTP_RANGE"] = range if range
    middleware.build(app).call(env)
  end

  def consume(body)
    chunks = []
    body.each { |chunk| chunks << chunk }
    chunks.join
  ensure
    body.close if body.respond_to?(:close)
  end
end
